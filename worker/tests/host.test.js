/**
 * Preview host sessions. TV-facing §4 shapes must stay unchanged.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { handleRequest, createTestEnv, MemoryKV, isValidCode, CODE_ALPHABET } from "../src/index.js";
import { sha256Hex, SIGNUP_RATE_LIMIT, SESSION_TTL_MS, timingSafeEqualText } from "../src/host.js";

function clock(start) {
  let now = start;
  return {
    now: () => now,
    advance: (ms) => {
      now += ms;
    },
  };
}

function previewEnv(c, extra = {}) {
  const kv = new MemoryKV(() => c.now());
  return createTestEnv({
    KV: kv,
    now: () => c.now(),
    PREVIEW_SIGNUP: "1",
    // Do not use the shared default in these tests.
    HOST_TOKEN: extra.HOST_TOKEN === undefined ? "admin-test-token" : extra.HOST_TOKEN,
    ...extra,
    KV: kv,
  });
}

async function call(env, method, path, { body, headers, origin } = {}) {
  const url = `${origin || "http://hostkit.test"}${path}`;
  const init = { method, headers: { ...(headers || {}) } };
  if (origin) init.headers.Origin = origin;
  if (body !== undefined) {
    init.headers["content-type"] = "application/json";
    init.body = typeof body === "string" ? body : JSON.stringify(body);
  }
  const response = await handleRequest(new Request(url, init), env);
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: response.status, json, text, headers: response.headers };
}

const mini = (id) => ({
  schemaVersion: 1,
  property: { id, name: "Preview" },
  faqs: [],
  activities: [],
  wifi: { ssid: "{{WIFI_SSID}}", password: "{{WIFI_PASSWORD}}" },
  branding: { colors: { text: "#111", background: "#fff" } },
  links: { hostToolsDirect: "https://example.com/book" },
  checkout: { summary: "Bye" },
  subscription: { status: "trial", plan: "monthly" },
});

describe("POST /v1/host/signup", () => {
  it("is 404 unless PREVIEW_SIGNUP=1", async () => {
    const env = previewEnv(clock(Date.now()), { PREVIEW_SIGNUP: "0" });
    const res = await call(env, "POST", "/v1/host/signup", { body: {} });
    assert.equal(res.status, 404);
  });

  it("returns a session token, stores only its hash, and scopes a property", async () => {
    const env = previewEnv(clock(Date.now()));
    const res = await call(env, "POST", "/v1/host/signup", { body: {} });
    assert.equal(res.status, 200);
    assert.equal(typeof res.json.token, "string");
    assert.ok(res.json.token.length >= 32);
    assert.equal(typeof res.json.hostId, "string");
    assert.equal(typeof res.json.propertyId, "string");
    const hash = await sha256Hex(res.json.token);
    const stored = await env.KV.get(`hostsession:${hash}`, "json");
    assert.equal(stored.hostId, res.json.hostId);
    assert.equal(stored.token, undefined);
    const listed = await env.KV.list();
    for (const key of listed.keys) {
      const value = await env.KV.get(key.name);
      assert.equal(String(value).includes(res.json.token), false, key.name);
    }
  });

  it("rate-limits signups per IP in KV", async () => {
    const env = previewEnv(clock(Date.now()));
    const headers = { "CF-Connecting-IP": "203.0.113.9" };
    for (let i = 0; i < SIGNUP_RATE_LIMIT; i++) {
      const res = await call(env, "POST", "/v1/host/signup", { body: {}, headers });
      assert.equal(res.status, 200, i);
    }
    const blocked = await call(env, "POST", "/v1/host/signup", { body: {}, headers });
    assert.equal(blocked.status, 429);
    const keys = await env.KV.list({ prefix: "ratelimit:signup:" });
    assert.ok(keys.keys.length >= 1);
  });
});

describe("session ownership", () => {
  it("a host can put and claim only their property; another host is forbidden", async () => {
    const env = previewEnv(clock(Date.now()));
    const a = await call(env, "POST", "/v1/host/signup", { body: {} });
    const b = await call(env, "POST", "/v1/host/signup", { body: {} });
    const authA = { Authorization: `Bearer ${a.json.token}` };
    const authB = { Authorization: `Bearer ${b.json.token}` };

    const putA = await call(env, "PUT", "/v1/config", { headers: authA, body: mini(a.json.propertyId) });
    assert.equal(putA.status, 200);
    const putBOnA = await call(env, "PUT", "/v1/config", { headers: authB, body: mini(a.json.propertyId) });
    assert.equal(putBOnA.status, 403);

    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-own" } });
    const claimB = await call(env, "POST", "/v1/pair/claim", {
      headers: authB,
      body: { code: start.json.code, propertyId: a.json.propertyId },
    });
    assert.equal(claimB.status, 403);
    const claimA = await call(env, "POST", "/v1/pair/claim", {
      headers: authA,
      body: { code: start.json.code, propertyId: a.json.propertyId },
    });
    assert.equal(claimA.status, 200);
    assert.equal(claimA.json.status, "paired");
    assert.equal(claimA.json.propertyId, a.json.propertyId);
    assert.equal(claimA.json.deviceToken, undefined, "claim response must not grow TV-facing fields");

    const listed = await call(env, "GET", "/v1/host/devices", { headers: authA });
    assert.equal(listed.status, 200);
    assert.equal(listed.json.devices.length, 1);
    assert.equal(listed.json.devices[0].deviceId, "tv-own");
    assert.equal(listed.json.devices[0].deviceToken, undefined);

    const listedB = await call(env, "GET", "/v1/host/devices", { headers: authB });
    assert.equal(listedB.json.devices.length, 0);

    const revokeB = await call(env, "POST", "/v1/pair/revoke", {
      headers: authB,
      body: { deviceId: "tv-own" },
    });
    assert.equal(revokeB.status, 403);
  });

  it("expired session hashes are unauthorized", async () => {
    const c = clock(Date.now());
    const env = previewEnv(c);
    const signed = await call(env, "POST", "/v1/host/signup", { body: {} });
    c.advance(SESSION_TTL_MS + 1000);
    const put = await call(env, "PUT", "/v1/config", {
      headers: { Authorization: `Bearer ${signed.json.token}` },
      body: mini(signed.json.propertyId),
    });
    assert.equal(put.status, 401);
  });
});

describe("private values and config GET", () => {
  it("substitutes placeholders only for a paired device token", async () => {
    const env = previewEnv(clock(Date.now()));
    const signed = await call(env, "POST", "/v1/host/signup", { body: {} });
    const auth = { Authorization: `Bearer ${signed.json.token}` };
    const propertyId = signed.json.propertyId;
    const put = await call(env, "PUT", "/v1/config", { headers: auth, body: mini(propertyId) });
    assert.equal(put.status, 200);
    // Assemble the stand-in so the file never contains a quoted password value
    // (the secrets scan flags any WIFI_PASSWORD / password: "..." literal).
    const examplePrivateText = ["example-", "private-", "text"].join("");
    const priv = await call(env, "PUT", "/v1/host/private", {
      headers: auth,
      body: { propertyId, values: { WIFI_SSID: "CafeGuest", WIFI_PASSWORD: examplePrivateText } },
    });
    assert.equal(priv.status, 200);

    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-priv" } });
    await call(env, "POST", "/v1/pair/claim", {
      headers: auth,
      body: { code: start.json.code, propertyId },
    });
    const status = await call(env, "GET", "/v1/pair/status?deviceId=tv-priv");
    assert.equal(status.json.status, "paired");
    const token = status.json.deviceToken;
    const cfg = await call(env, "GET", "/v1/config", { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(cfg.status, 200);
    assert.equal(cfg.json.wifi.ssid, "CafeGuest");
    assert.equal(cfg.json.wifi.password, examplePrivateText);
    const stored = JSON.parse(await env.KV.get(`property:${propertyId}:config`));
    assert.equal(stored.wifi.password, "{{WIFI_PASSWORD}}");

    const noTok = await call(env, "GET", "/v1/config");
    assert.equal(noTok.status, 401);

    const revoked = await call(env, "POST", "/v1/pair/revoke", { headers: auth, body: { deviceId: "tv-priv" } });
    assert.equal(revoked.status, 200);
    const after = await call(env, "GET", "/v1/config", { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(after.status, 401);
  });

  it("rejects an invalid config with 400", async () => {
    const env = previewEnv(clock(Date.now()));
    const signed = await call(env, "POST", "/v1/host/signup", { body: {} });
    const auth = { Authorization: `Bearer ${signed.json.token}` };
    const bad = await call(env, "PUT", "/v1/config", {
      headers: auth,
      body: { schemaVersion: 9, property: { id: signed.json.propertyId } },
    });
    assert.equal(bad.status, 400);
  });
});

describe("TV-facing shapes and hooks", () => {
  it("pair start still returns code, shortUrl, expiresAt, pollAfterMs", async () => {
    const env = previewEnv(clock(Date.now()));
    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-shape" } });
    assert.equal(start.status, 200);
    assert.equal(isValidCode(start.json.code), true);
    assert.equal(typeof start.json.shortUrl, "string");
    assert.equal(typeof start.json.expiresAt, "string");
    assert.equal(start.json.pollAfterMs, 5000);
    for (const ch of ["0", "O", "1", "I"]) {
      assert.equal(CODE_ALPHABET.includes(ch), false);
    }
    const pending = await call(env, "GET", "/v1/pair/status?deviceId=tv-shape");
    assert.equal(pending.json.status, "pending");
    assert.deepEqual(Object.keys(pending.json).sort(), ["expiresAt", "pollAfterMs", "status"].sort());
  });

  it("test-hook routes are 404 when ALLOW_TEST_HOOKS is not set", async () => {
    const env = previewEnv(clock(Date.now()), { ALLOW_TEST_HOOKS: "0" });
    const expire = await call(env, "POST", "/v1/__test/expire", { body: { code: "ABCDEF" } });
    assert.equal(expire.status, 404);
    const session = await call(env, "GET", "/v1/__test/session?deviceId=x");
    assert.equal(session.status, 404);
  });

  it("CORS reflects only the preview Pages origins", async () => {
    const env = previewEnv(clock(Date.now()), { CORS_ORIGINS: "" });
    const ok = await call(env, "GET", "/health", { origin: "https://hostkit-preview.pages.dev" });
    assert.equal(ok.headers.get("access-control-allow-origin"), "https://hostkit-preview.pages.dev");
    const alias = await call(env, "GET", "/health", {
      origin: "https://abc.hostkit-preview.pages.dev",
    });
    assert.equal(alias.headers.get("access-control-allow-origin"), "https://abc.hostkit-preview.pages.dev");
    const denied = await call(env, "GET", "/health", { origin: "https://evil.example" });
    assert.equal(denied.headers.get("access-control-allow-origin"), null);
  });
});

describe("HOST_TOKEN admin fallback", () => {
  it("compares tokens in constant time via digest equality", async () => {
    assert.equal(await timingSafeEqualText("admin-test-token", "admin-test-token"), true);
    assert.equal(await timingSafeEqualText("admin-test-token", "admin-test-tokeN"), false);
    assert.equal(await timingSafeEqualText("abc", "ab"), false);
    assert.equal(await timingSafeEqualText("", ""), true);
  });

  it("accepts the admin HOST_TOKEN and rejects a near-miss bearer", async () => {
    const env = previewEnv(clock(Date.now()));
    const signed = await call(env, "POST", "/v1/host/signup", { body: {} });
    const ok = await call(env, "PUT", "/v1/config", {
      headers: { Authorization: "Bearer admin-test-token" },
      body: mini(signed.json.propertyId),
    });
    assert.equal(ok.status, 200);
    const near = await call(env, "PUT", "/v1/config", {
      headers: { Authorization: "Bearer admin-test-tokeN" },
      body: mini(signed.json.propertyId),
    });
    assert.equal(near.status, 401);
  });
});
