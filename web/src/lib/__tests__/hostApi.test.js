import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createHostApi,
  TV_SERVICE_NOT_LIVE,
  loadStoredSession,
  storeSession,
  clearSession,
} from "../hostApi.js";
import { isApiConfigured, normalizeApiBase } from "../apiConfig.js";

test("empty api base is not live and throws a friendly error", async () => {
  assert.equal(isApiConfigured({ apiBase: "" }), false);
  const api = createHostApi({ apiBase: "" });
  assert.equal(api.live, false);
  await assert.rejects(() => api.signup(), (err) => err.message === TV_SERVICE_NOT_LIVE);
});

test("signup, claim, publish, and private put use the session token", async () => {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify({ ok: true, status: "published" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };
  const api = createHostApi({
    apiBase: "https://hostkit-api-preview.example.workers.dev",
    getToken: () => "session-token",
    fetchImpl,
  });
  await api.signup();
  await api.claim("ABC234", "p1");
  await api.putConfig({ schemaVersion: 1 });
  await api.putPrivate("p1", { WIFI_SSID: "x" });
  await api.revoke({ deviceId: "tv-1" });
  await api.listDevices();
  assert.equal(calls[0].url.endsWith("/v1/host/signup"), true);
  assert.equal(calls[1].init.headers.Authorization, "Bearer session-token");
  assert.equal(JSON.parse(calls[1].init.body).code, "ABC234");
  assert.equal(calls[2].url.endsWith("/v1/config"), true);
  assert.equal(calls[2].init.method, "PUT");
  assert.equal(calls[3].url.endsWith("/v1/host/private"), true);
});

test("session is stored only in the provided storage", () => {
  const mem = new Map();
  const storage = {
    getItem: (k) => (mem.has(k) ? mem.get(k) : null),
    setItem: (k, v) => mem.set(k, v),
    removeItem: (k) => mem.delete(k),
  };
  storeSession({ token: "t", hostId: "h", propertyId: "p", expiresAt: "e" }, storage);
  assert.equal(loadStoredSession(storage).hostId, "h");
  clearSession(storage);
  assert.equal(loadStoredSession(storage), null);
});

test("normalizeApiBase strips a trailing slash", () => {
  assert.equal(
    normalizeApiBase("https://hostkit-api-preview.example.workers.dev/"),
    "https://hostkit-api-preview.example.workers.dev"
  );
});
