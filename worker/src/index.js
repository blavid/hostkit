/**
 * HostKit Worker API (SPEC §4).
 * export default { fetch(req, env) }
 *
 * env.KV          — Cloudflare KV (or MemoryKV locally)
 * env.HOST_TOKEN  — stub host bearer (default "host-preview")
 * env.PUBLIC_BASE — origin used in shortUrl (no trailing slash)
 * env.now         — optional () => epoch ms, for tests
 * env.ALLOW_TEST_HOOKS — "1" enables local-only expire/inspect routes
 * env.DEFAULT_CONFIG   — optional JSON string seeded as property "eaglewood"
 */
import { CODE_ALPHABET, isValidCode, makeCode, newExpiresAt, isExpired, PAIR_TTL_MS, POLL_AFTER_MS } from "./pair.js";
import { guestContentAllowed, graceEndsAt, DEFAULT_GRACE_DAYS } from "./grace.js";
import { MemoryKV } from "./kv.js";
import { qrPng } from "./qr.js";
import {
  authorizeHost,
  assertOwnsProperty,
  assertOwnsDevice,
  hostSignup,
  listHostDevices,
  putPrivateValues,
  substitutePrivate,
  rememberDevice,
  markDeviceRevoked,
  isAllowedOrigin,
} from "./host.js";

export { MemoryKV, isValidCode, makeCode, CODE_ALPHABET, guestContentAllowed, graceEndsAt, DEFAULT_GRACE_DAYS };

const PAIR_TTL_SEC = Math.floor(PAIR_TTL_MS / 1000);
// Keep the KV record briefly past logical expiry so claim can return 410, not 404.
const PAIR_KV_TTL_SEC = PAIR_TTL_SEC + 120;
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

export default {
  async fetch(request, env) {
    return handleRequest(request, env || {});
  },
};

export async function handleRequest(request, env) {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") {
    return cors(new Response(null, { status: 204 }), request, env);
  }
  try {
    const response = await route(request, url, env);
    return cors(response, request, env);
  } catch (err) {
    const message = err && err.message ? err.message : "internal error";
    return cors(json({ error: "internal", message }, 500), request, env);
  }
}

async function route(request, url, env) {
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const method = request.method.toUpperCase();

  if (method === "GET" && path === "/health") {
    return json({ ok: true }, 200);
  }

  if (method === "POST" && path === "/v1/pair/start") return pairStart(request, env, url);
  if (method === "GET" && path === "/v1/pair/status") return pairStatus(request, env, url);
  if (method === "POST" && path === "/v1/pair/claim") return pairClaim(request, env);
  if (method === "POST" && path === "/v1/pair/revoke") return pairRevoke(request, env);
  if (method === "GET" && path === "/v1/pair/qr") return pairQr(url);
  if (method === "GET" && path === "/v1/config") return getConfig(request, env);
  if (method === "PUT" && path === "/v1/config") return putConfig(request, env);
  if (method === "POST" && path === "/v1/host/signup") return hostSignup(request, env);
  if (method === "GET" && path === "/v1/host/devices") return listHostDevices(request, env);
  if (method === "PUT" && path === "/v1/host/private") return putPrivateValues(request, env);

  if (env.ALLOW_TEST_HOOKS === "1") {
    if (method === "POST" && path === "/v1/__test/expire") return testExpire(request, env);
    if (method === "GET" && path === "/v1/__test/session") return testSession(url, env);
  }

  return json({ error: "not_found" }, 404);
}

function nowMs(env) {
  if (typeof env.now === "function") return env.now();
  return Date.now();
}

function publicBase(env, url) {
  const fromEnv = env.PUBLIC_BASE ? String(env.PUBLIC_BASE).replace(/\/+$/, "") : "";
  if (fromEnv) return fromEnv;
  return url.origin;
}

function hostToken(env) {
  return env.HOST_TOKEN || "host-preview";
}

function bearer(request) {
  const header = request.headers.get("Authorization") || request.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : "";
}


async function readJson(request) {
  const text = await request.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw Object.assign(new Error("invalid json"), { httpStatus: 400 });
  }
}

async function pairStart(request, env, url) {
  const body = await safeJson(request);
  if (body.error) return body.error;
  const deviceId = String(body.json.deviceId || "").trim();
  if (!deviceId || deviceId.length > 200) return json({ error: "invalid_device_id" }, 400);

  const kv = env.KV;
  const now = nowMs(env);
  const previous = await kv.get(`pair:device:${deviceId}`, "json");
  if (previous && previous.code) {
    await kv.delete(`pair:code:${previous.code}`);
  }

  let code = makeCode();
  for (let i = 0; i < 8; i++) {
    const taken = await kv.get(`pair:code:${code}`);
    if (!taken) break;
    code = makeCode();
  }

  const expiresAt = newExpiresAt(now, PAIR_TTL_MS);
  const session = {
    code,
    deviceId,
    status: "pending",
    expiresAt,
    createdAt: new Date(now).toISOString(),
  };
  await kv.put(`pair:code:${code}`, JSON.stringify(session), { expirationTtl: PAIR_KV_TTL_SEC });
  await kv.put(`pair:device:${deviceId}`, JSON.stringify({ code, expiresAt }), { expirationTtl: PAIR_KV_TTL_SEC });

  const base = publicBase(env, url);
  const shortUrl = `${base}/pair/${code}`;
  const qrUrl = `${base}/v1/pair/qr?code=${encodeURIComponent(code)}`;
  return json({
    code,
    shortUrl,
    qrUrl,
    expiresAt,
    pollAfterMs: POLL_AFTER_MS,
  }, 200);
}

async function pairStatus(request, env, url) {
  const deviceId = String(url.searchParams.get("deviceId") || "").trim();
  if (!deviceId) return json({ error: "invalid_device_id" }, 400);
  const kv = env.KV;
  const now = nowMs(env);
  const pointer = await kv.get(`pair:device:${deviceId}`, "json");
  if (!pointer || !pointer.code) return json({ status: "expired" }, 200);
  const session = await kv.get(`pair:code:${pointer.code}`, "json");
  if (!session) return json({ status: "expired" }, 200);
  if (session.status === "paired") {
    return json({
      status: "paired",
      deviceToken: session.deviceToken,
      propertyId: session.propertyId,
    }, 200);
  }
  if (session.status !== "pending" || isExpired(session.expiresAt, now)) {
    return json({ status: "expired" }, 200);
  }
  return json({ status: "pending", expiresAt: session.expiresAt, pollAfterMs: POLL_AFTER_MS }, 200);
}

// Serialize claims for the same code so two in-flight requests cannot both succeed.
const claimLocks = new Map();

async function withClaimLock(code, fn) {
  const key = code.toUpperCase();
  while (claimLocks.has(key)) {
    await claimLocks.get(key);
  }
  let release;
  const pending = new Promise((resolve) => {
    release = resolve;
  });
  claimLocks.set(key, pending);
  try {
    return await fn();
  } finally {
    claimLocks.delete(key);
    release();
  }
}

async function pairClaim(request, env) {
  const authz = await authorizeHost(request, env);
  if (authz.error) return authz.error;
  const body = await safeJson(request);
  if (body.error) return body.error;
  const code = String(body.json.code || "").trim().toUpperCase();
  const propertyId = String(body.json.propertyId || "").trim();
  if (!isValidCode(code)) return json({ error: "invalid_code" }, 400);
  if (!propertyId) return json({ error: "invalid_property_id" }, 400);
  const owned = await assertOwnsProperty(env, authz.auth, propertyId);
  if (owned) return owned;

  return withClaimLock(code, async () => {
    const kv = env.KV;
    const now = nowMs(env);
    const session = await kv.get(`pair:code:${code}`, "json");
    if (!session) return json({ error: "not_found" }, 404);
    if (session.status === "paired") return json({ error: "already_claimed" }, 409);
    if (session.status !== "pending" || isExpired(session.expiresAt, now)) {
      return json({ error: "expired" }, 410);
    }

    const deviceToken = randomToken();
    const paired = {
      ...session,
      status: "paired",
      propertyId,
      deviceToken,
      pairedAt: new Date(now).toISOString(),
    };
    await kv.put(`pair:code:${code}`, JSON.stringify(paired));
    await kv.put(`pair:device:${session.deviceId}`, JSON.stringify({
      code,
      expiresAt: session.expiresAt,
      status: "paired",
    }));
    await kv.put(`device:${deviceToken}`, JSON.stringify({
      propertyId,
      deviceId: session.deviceId,
      hostId: authz.auth.hostId || null,
      revoked: false,
      issuedAt: new Date(now).toISOString(),
    }));
    await rememberDevice(env, authz.auth, {
      deviceId: session.deviceId,
      propertyId,
      pairedAt: paired.pairedAt,
    });

    return json({
      status: "paired",
      propertyId,
      deviceId: session.deviceId,
    }, 200);
  });
}

async function pairRevoke(request, env) {
  const authz = await authorizeHost(request, env);
  if (authz.error) return authz.error;
  const body = await safeJson(request);
  if (body.error) return body.error;
  const kv = env.KV;
  let token = String(body.json.deviceToken || "").trim();
  if (!token && body.json.deviceId) {
    token = await tokenForDevice(kv, String(body.json.deviceId));
  }
  if (!token) return json({ error: "not_found" }, 404);
  const record = await kv.get(`device:${token}`, "json");
  if (!record) return json({ error: "not_found" }, 404);
  const owned = await assertOwnsDevice(env, authz.auth, record);
  if (owned) return owned;
  record.revoked = true;
  record.revokedAt = new Date(nowMs(env)).toISOString();
  await kv.put(`device:${token}`, JSON.stringify(record));
  await markDeviceRevoked(env, authz.auth, record.deviceId);
  return json({ status: "revoked" }, 200);
}

async function tokenForDevice(kv, deviceId) {
  const listed = await kv.list({ prefix: "device:" });
  for (const key of listed.keys) {
    const rec = await kv.get(key.name, "json");
    if (rec && rec.deviceId === deviceId && rec.revoked !== true) {
      return key.name.slice("device:".length);
    }
  }
  return "";
}

async function pairQr(url) {
  const code = String(url.searchParams.get("code") || "").trim().toUpperCase();
  if (!isValidCode(code)) return json({ error: "invalid_code" }, 400);
  // Payload already embeds the code: the short path the host opens.
  const target = url.searchParams.get("url") || `${url.origin}/pair/${code}`;
  const png = qrPng(target);
  return new Response(png, {
    status: 200,
    headers: {
      "content-type": "image/png",
      "cache-control": "no-store",
      "content-length": String(png.length),
    },
  });
}

async function getConfig(request, env) {
  const token = bearer(request);
  if (!token) return json({ error: "unauthorized" }, 401);
  const record = await env.KV.get(`device:${token}`, "json");
  if (!record || record.revoked === true) return json({ error: "unauthorized" }, 401);
  await ensureDefaultConfig(env);
  const stored = await env.KV.get(`property:${record.propertyId}:config`);
  if (!stored) return json({ error: "not_found" }, 404);
  const raw = await substitutePrivate(env, record.propertyId, stored);
  const config = JSON.parse(raw);
  const etag = await etagFor(raw);
  const incoming = request.headers.get("If-None-Match") || "";
  if (incoming && incoming === etag) {
    return new Response(null, { status: 304, headers: { ETag: etag, "cache-control": "no-store" } });
  }
  return new Response(raw, {
    status: 200,
    headers: {
      ...JSON_HEADERS,
      ETag: etag,
      "x-hostkit-property": record.propertyId,
      "x-hostkit-guest-allowed": guestContentAllowed(config.subscription, nowMs(env)) ? "1" : "0",
    },
  });
}

async function putConfig(request, env) {
  const authz = await authorizeHost(request, env);
  if (authz.error) return authz.error;
  const body = await safeJson(request);
  if (body.error) return body.error;
  const config = body.json;
  const reason = configRejectReason(config);
  if (reason) return json({ error: reason }, 400);
  const propertyId = config.property.id;
  const owned = await assertOwnsProperty(env, authz.auth, propertyId);
  if (owned) return owned;
  const raw = JSON.stringify(config);
  await env.KV.put(`property:${propertyId}:config`, raw);
  const etag = await etagFor(raw);
  return json({ status: "published", propertyId, etag }, 200);
}

function configRejectReason(config) {
  if (!config || typeof config !== "object") return "invalid_config";
  if (config.schemaVersion !== 1) return "unsupported_schema";
  if (!config.property || !config.property.id) return "invalid_property";
  if (!Array.isArray(config.faqs) || !Array.isArray(config.activities)) return "invalid_config";
  return "";
}

export async function ensureDefaultConfig(env) {
  if (!env.DEFAULT_CONFIG) return;
  const existing = await env.KV.get("property:eaglewood:config");
  if (existing) return;
  await env.KV.put("property:eaglewood:config", env.DEFAULT_CONFIG);
}

async function testExpire(request, env) {
  const body = await safeJson(request);
  if (body.error) return body.error;
  let code = String(body.json.code || "").trim().toUpperCase();
  const deviceId = String(body.json.deviceId || "").trim();
  if (!code && deviceId) {
    const pointer = await env.KV.get(`pair:device:${deviceId}`, "json");
    if (pointer && pointer.code) code = pointer.code;
  }
  if (!code) return json({ error: "not_found" }, 404);
  const session = await env.KV.get(`pair:code:${code}`, "json");
  if (!session) return json({ error: "not_found" }, 404);
  session.expiresAt = new Date(nowMs(env) - 1000).toISOString();
  session.status = "expired";
  await env.KV.put(`pair:code:${code}`, JSON.stringify(session));
  return json({ status: "expired", code }, 200);
}

async function testSession(url, env) {
  const deviceId = String(url.searchParams.get("deviceId") || "").trim();
  const pointer = await env.KV.get(`pair:device:${deviceId}`, "json");
  if (!pointer) return json({ error: "not_found" }, 404);
  const session = await env.KV.get(`pair:code:${pointer.code}`, "json");
  return json({ pointer, session: session && { ...session, deviceToken: session.deviceToken ? "[redacted]" : undefined } }, 200);
}

async function safeJson(request) {
  try {
    const jsonBody = await readJson(request);
    return { json: jsonBody };
  } catch (err) {
    return { error: json({ error: "invalid_json" }, 400) };
  }
}

async function etagFor(text) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  const hex = [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `"${hex.slice(0, 32)}"`;
}

function randomToken() {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function json(body, status) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function cors(response, request, env) {
  const headers = new Headers(response.headers);
  const origin = request ? (request.headers.get("Origin") || request.headers.get("origin") || "") : "";
  if (origin && isAllowedOrigin(origin, env || {})) {
    headers.set("access-control-allow-origin", origin);
    headers.set("vary", "Origin");
  }
  headers.set("access-control-allow-headers", "Authorization, Content-Type, If-None-Match");
  headers.set("access-control-allow-methods", "GET, POST, PUT, OPTIONS");
  return new Response(response.body, { status: response.status, headers });
}

export function createTestEnv(overrides = {}) {
  const kv = overrides.KV || new MemoryKV(overrides.now || (() => Date.now()));
  return {
    KV: kv,
    HOST_TOKEN: "host-preview",
    PUBLIC_BASE: "http://hostkit.test",
    ALLOW_TEST_HOOKS: "1",
    CORS_ORIGINS: "*",
    now: () => Date.now(),
    ...overrides,
    KV: kv,
  };
}
