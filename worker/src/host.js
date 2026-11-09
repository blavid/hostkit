/**
 * Preview host sessions (M4). New host-facing routes only.
 * TV-facing §4 shapes are unchanged.
 *
 * Session tokens are shown once to the browser; KV stores only a SHA-256 hash
 * plus an expiry. Rate limits live in KV. HOST_TOKEN remains an admin fallback.
 */
import { isExpired } from "./pair.js";

export const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
export const SIGNUP_RATE_LIMIT = 8;
export const SIGNUP_WINDOW_MS = 60 * 60 * 1000;

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

export function json(body, status) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

export function bearer(request) {
  const header = request.headers.get("Authorization") || request.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : "";
}

export async function sha256Hex(value) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(String(value)));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Compare two strings in constant time (SHA-256 digest, then a fixed 32-byte XOR).
 * Used for the HOST_TOKEN admin fallback so the compare does not short-circuit
 * on the first differing character. Works in Node tests and the Workers runtime
 * without node:crypto.
 */
export async function timingSafeEqualText(a, b) {
  const enc = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(String(a ?? ""))),
    crypto.subtle.digest("SHA-256", enc.encode(String(b ?? ""))),
  ]);
  const x = new Uint8Array(left);
  const y = new Uint8Array(right);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export function randomToken() {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function nowMs(env) {
  if (typeof env.now === "function") return env.now();
  return Date.now();
}

export function clientIp(request) {
  return (
    request.headers.get("CF-Connecting-IP") ||
    request.headers.get("cf-connecting-ip") ||
    (request.headers.get("X-Forwarded-For") || "").split(",")[0].trim() ||
    "unknown"
  );
}

/**
 * Increment a KV counter for the current window. Returns false when over limit.
 */
export async function consumeRateLimit(env, key, limit, windowMs, now) {
  const windowSec = Math.max(60, Math.floor(windowMs / 1000));
  const bucket = Math.floor(now / windowMs);
  const kvKey = `ratelimit:${key}:${bucket}`;
  const current = Number((await env.KV.get(kvKey)) || "0");
  if (current >= limit) return false;
  await env.KV.put(kvKey, String(current + 1), { expirationTtl: windowSec });
  return true;
}

export async function hostSignup(request, env) {
  if (env.PREVIEW_SIGNUP !== "1") return json({ error: "not_found" }, 404);
  const now = nowMs(env);
  const ip = clientIp(request);
  const allowed = await consumeRateLimit(env, `signup:${ip}`, SIGNUP_RATE_LIMIT, SIGNUP_WINDOW_MS, now);
  if (!allowed) return json({ error: "rate_limited" }, 429);

  const hostId = `h_${randomToken().slice(0, 16)}`;
  const propertyId = `p_${randomToken().slice(0, 16)}`;
  const token = randomToken() + randomToken();
  const hash = await sha256Hex(token);
  const expiresAt = new Date(now + SESSION_TTL_MS).toISOString();
  const ttlSec = Math.max(60, Math.floor(SESSION_TTL_MS / 1000));

  await env.KV.put(`hostsession:${hash}`, JSON.stringify({ hostId, expiresAt }), { expirationTtl: ttlSec });
  await env.KV.put(
    `host:${hostId}`,
    JSON.stringify({ hostId, propertyIds: [propertyId], createdAt: new Date(now).toISOString() }),
  );
  await env.KV.put(`property:${propertyId}:owner`, hostId);
  await env.KV.put(
    `host:${hostId}:devices`,
    JSON.stringify([]),
  );

  return json({ hostId, token, expiresAt, propertyId }, 200);
}

export async function authorizeHost(request, env) {
  const token = bearer(request);
  if (!token) return { error: json({ error: "unauthorized" }, 401) };

  const admin = env.HOST_TOKEN || "";
  if (admin && await timingSafeEqualText(token, admin)) {
    return { auth: { role: "admin", hostId: null } };
  }

  const hash = await sha256Hex(token);
  const rec = await env.KV.get(`hostsession:${hash}`, "json");
  if (!rec || !rec.hostId) return { error: json({ error: "unauthorized" }, 401) };
  if (isExpired(rec.expiresAt, nowMs(env))) return { error: json({ error: "unauthorized" }, 401) };
  return { auth: { role: "host", hostId: rec.hostId } };
}

export async function assertOwnsProperty(env, auth, propertyId) {
  if (!propertyId) return json({ error: "invalid_property_id" }, 400);
  if (auth.role === "admin") return null;
  const owner = await env.KV.get(`property:${propertyId}:owner`);
  if (owner !== auth.hostId) return json({ error: "forbidden" }, 403);
  return null;
}

export async function assertOwnsDevice(env, auth, record) {
  if (!record) return json({ error: "not_found" }, 404);
  if (auth.role === "admin") return null;
  if (record.hostId && record.hostId === auth.hostId) return null;
  if (record.propertyId) {
    const owner = await env.KV.get(`property:${record.propertyId}:owner`);
    if (owner === auth.hostId) return null;
  }
  return json({ error: "forbidden" }, 403);
}

export async function rememberDevice(env, auth, { deviceId, propertyId, pairedAt }) {
  if (!auth || auth.role !== "host" || !auth.hostId) return;
  const key = `host:${auth.hostId}:devices`;
  const list = (await env.KV.get(key, "json")) || [];
  const next = list.filter((d) => d.deviceId !== deviceId);
  next.push({ deviceId, propertyId, pairedAt, revoked: false });
  await env.KV.put(key, JSON.stringify(next));
}

export async function markDeviceRevoked(env, auth, deviceId) {
  if (!auth || auth.role !== "host" || !auth.hostId || !deviceId) return;
  const key = `host:${auth.hostId}:devices`;
  const list = (await env.KV.get(key, "json")) || [];
  const next = list.map((d) => (d.deviceId === deviceId ? { ...d, revoked: true } : d));
  await env.KV.put(key, JSON.stringify(next));
}

export async function listHostDevices(request, env) {
  const { error, auth } = await authorizeHost(request, env);
  if (error) return error;
  if (auth.role === "admin") {
    return json({ devices: [], note: "admin" }, 200);
  }
  const list = (await env.KV.get(`host:${auth.hostId}:devices`, "json")) || [];
  // Never include a device token.
  const devices = list.map(({ deviceId, propertyId, pairedAt, revoked }) => ({
    deviceId,
    propertyId,
    pairedAt,
    revoked: Boolean(revoked),
  }));
  return json({ devices }, 200);
}

const PRIVATE_KEYS = new Set([
  "WIFI_SSID",
  "WIFI_PASSWORD",
  "HOST_PHONE",
  "DOOR_CODE",
  "HOST_EMAIL",
  "PROPERTY_ADDRESS",
  "CHECKOUT_STEP_1",
  "GUEST_PATH_KEY",
]);

export async function putPrivateValues(request, env) {
  const { error, auth } = await authorizeHost(request, env);
  if (error) return error;
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const propertyId = String(body.propertyId || "").trim();
  const denied = await assertOwnsProperty(env, auth, propertyId);
  if (denied) return denied;
  const values = {};
  const incoming = body.values && typeof body.values === "object" ? body.values : {};
  for (const [key, value] of Object.entries(incoming)) {
    if (!PRIVATE_KEYS.has(key)) continue;
    if (typeof value === "string" && value.length) values[key] = value;
  }
  await env.KV.put(`property:${propertyId}:private`, JSON.stringify({ values }));
  return json({ status: "saved", propertyId, keys: Object.keys(values) }, 200);
}

export async function substitutePrivate(env, propertyId, raw) {
  const rec = await env.KV.get(`property:${propertyId}:private`, "json");
  const values = rec && rec.values ? rec.values : rec || {};
  if (!values || typeof values !== "object") return raw;
  let out = raw;
  for (const [key, value] of Object.entries(values)) {
    if (typeof value !== "string") continue;
    out = out.split(`{{${key}}}`).join(value);
  }
  return out;
}

export function isAllowedOrigin(origin, env) {
  if (!origin) return false;
  const extra = String(env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  if (extra.includes("*") || extra.includes(origin)) return true;
  if (origin === "https://hostkit-preview.pages.dev") return true;
  try {
    const url = new URL(origin);
    if (url.protocol === "https:" && url.hostname.endsWith(".hostkit-preview.pages.dev")) {
      return true;
    }
  } catch {
    return false;
  }
  return false;
}
