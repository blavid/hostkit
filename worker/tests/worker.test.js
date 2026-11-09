/**
 * HostKit Worker unit tests. No npm dependencies (node --test + in-memory KV).
 * Covers: 15-minute code expiry, alphabet exclusions, claim race, revoke → 401,
 * and 14-day grace math.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  handleRequest,
  createTestEnv,
  ensureDefaultConfig,
  isValidCode,
  makeCode,
  CODE_ALPHABET,
  graceEndsAt,
  guestContentAllowed,
  DEFAULT_GRACE_DAYS,
  MemoryKV,
} from "../src/index.js";

const fixture = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), "..", "..", "schema", "eaglewood.customer0.json"),
  "utf8",
);

function clock(start) {
  let now = start;
  return {
    now: () => now,
    set: (t) => {
      now = t;
    },
    advance: (ms) => {
      now += ms;
    },
  };
}

function envWithClock(c, extra = {}) {
  const kv = new MemoryKV(() => c.now());
  return createTestEnv({
    KV: kv,
    now: () => c.now(),
    DEFAULT_CONFIG: fixture,
    ...extra,
  });
}

async function call(env, method, path, { body, headers, origin } = {}) {
  const url = `${origin || "http://hostkit.test"}${path}`;
  const init = { method, headers: { ...(headers || {}) } };
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

const HOST = { Authorization: "Bearer host-preview" };

describe("alphabet exclusions", () => {
  it("rejects 0, O, 1, and I and requires 6 alphabet characters", () => {
    assert.equal(isValidCode("ABC234"), true);
    assert.equal(isValidCode("ABCDEF"), true);
    assert.equal(isValidCode("abc234"), true);
    assert.equal(isValidCode("AB0CDE"), false);
    assert.equal(isValidCode("ABOCDE"), false);
    assert.equal(isValidCode("AB1CDE"), false);
    assert.equal(isValidCode("ABICDE"), false);
    assert.equal(isValidCode("ABC23"), false);
    assert.equal(isValidCode("ABC2345"), false);
    assert.equal(isValidCode(""), false);
    for (const ch of ["0", "O", "1", "I"]) {
      assert.equal(CODE_ALPHABET.includes(ch), false, `alphabet contains ${ch}`);
    }
  });

  it("never generates a forbidden character", () => {
    for (let i = 0; i < 400; i++) {
      const code = makeCode();
      assert.equal(isValidCode(code), true, code);
      assert.equal(/[01OI]/.test(code), false, code);
      assert.equal(code.length, 6);
    }
  });
});

describe("15-minute code expiry", () => {
  it("status is pending before 15 minutes and expired after", async () => {
    const t0 = Date.parse("2026-11-09T20:00:00Z");
    const c = clock(t0);
    const env = envWithClock(c);
    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-1" } });
    assert.equal(start.status, 200);
    assert.equal(isValidCode(start.json.code), true);
    assert.equal(start.json.pollAfterMs, 5000);
    assert.equal(Date.parse(start.json.expiresAt), t0 + 15 * 60 * 1000);
    assert.match(start.json.shortUrl, new RegExp(`/pair/${start.json.code}$`));

    const pending = await call(env, "GET", "/v1/pair/status?deviceId=tv-1");
    assert.equal(pending.json.status, "pending");

    c.advance(15 * 60 * 1000 - 1);
    const still = await call(env, "GET", "/v1/pair/status?deviceId=tv-1");
    assert.equal(still.json.status, "pending");

    c.advance(2);
    const expired = await call(env, "GET", "/v1/pair/status?deviceId=tv-1");
    assert.equal(expired.json.status, "expired");

    const claim = await call(env, "POST", "/v1/pair/claim", {
      headers: HOST,
      body: { code: start.json.code, propertyId: "eaglewood" },
    });
    assert.equal(claim.status, 410);
  });

  it("a new start invalidates the previous code for that device", async () => {
    const env = envWithClock(clock(Date.now()));
    const first = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-2" } });
    const second = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-2" } });
    assert.notEqual(first.json.code, second.json.code);
    const claimOld = await call(env, "POST", "/v1/pair/claim", {
      headers: HOST,
      body: { code: first.json.code, propertyId: "eaglewood" },
    });
    assert.ok(claimOld.status === 404 || claimOld.status === 410);
    const claimNew = await call(env, "POST", "/v1/pair/claim", {
      headers: HOST,
      body: { code: second.json.code, propertyId: "eaglewood" },
    });
    assert.equal(claimNew.status, 200);
    assert.equal(claimNew.json.status, "paired");
  });
});

describe("claim race", () => {
  it("only one of two concurrent claims succeeds", async () => {
    const env = envWithClock(clock(Date.now()));
    await ensureDefaultConfig(env);
    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-race" } });
    const code = start.json.code;
    const [a, b] = await Promise.all([
      call(env, "POST", "/v1/pair/claim", { headers: HOST, body: { code, propertyId: "eaglewood" } }),
      call(env, "POST", "/v1/pair/claim", { headers: HOST, body: { code, propertyId: "eaglewood" } }),
    ]);
    const statuses = [a.status, b.status].sort();
    assert.deepEqual(statuses, [200, 409]);
    const status = await call(env, "GET", "/v1/pair/status?deviceId=tv-race");
    assert.equal(status.json.status, "paired");
    assert.equal(typeof status.json.deviceToken, "string");
    assert.ok(status.json.deviceToken.length >= 24);
  });
});

describe("revoke returns 401", () => {
  it("GET /v1/config is 401 after the host revokes the device token", async () => {
    const env = envWithClock(clock(Date.now()));
    await ensureDefaultConfig(env);
    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-rev" } });
    const claimed = await call(env, "POST", "/v1/pair/claim", {
      headers: HOST,
      body: { code: start.json.code, propertyId: "eaglewood" },
    });
    assert.equal(claimed.status, 200);
    const paired = await call(env, "GET", "/v1/pair/status?deviceId=tv-rev");
    const token = paired.json.deviceToken;
    const ok = await call(env, "GET", "/v1/config", { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(ok.status, 200);
    const cfg = JSON.parse(ok.text);
    assert.equal(cfg.schemaVersion, 1);
    assert.equal(cfg.property.id, "eaglewood");
    assert.equal(cfg.wifi.password.includes("{{"), true);

    const etag = ok.headers.get("etag");
    const cached = await call(env, "GET", "/v1/config", {
      headers: { Authorization: `Bearer ${token}`, "If-None-Match": etag },
    });
    assert.equal(cached.status, 304);

    const revoked = await call(env, "POST", "/v1/pair/revoke", {
      headers: HOST,
      body: { deviceToken: token },
    });
    assert.equal(revoked.status, 200);
    const after = await call(env, "GET", "/v1/config", { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(after.status, 401);

    const missing = await call(env, "GET", "/v1/config");
    assert.equal(missing.status, 401);
  });

  it("claim and put require the host bearer stub", async () => {
    const env = envWithClock(clock(Date.now()));
    const start = await call(env, "POST", "/v1/pair/start", { body: { deviceId: "tv-auth" } });
    const claim = await call(env, "POST", "/v1/pair/claim", {
      body: { code: start.json.code, propertyId: "eaglewood" },
    });
    assert.equal(claim.status, 401);
    const put = await call(env, "PUT", "/v1/config", { body: { schemaVersion: 1, property: { id: "x" }, faqs: [], activities: [] } });
    assert.equal(put.status, 401);
  });
});

describe("14-day grace math", () => {
  it("graceEndsAt is 14 days after lapse", () => {
    assert.equal(DEFAULT_GRACE_DAYS, 14);
    assert.equal(graceEndsAt("2026-01-01T00:00:00.000Z", 14), "2026-01-15T00:00:00.000Z");
    assert.equal(graceEndsAt("2026-02-01T12:00:00.000Z", 14), "2026-02-15T12:00:00.000Z");
  });

  it("guest content stays up through grace and stops after", () => {
    const now = Date.parse("2026-03-10T00:00:00Z");
    assert.equal(guestContentAllowed({ status: "active", plan: "monthly" }, now), true);
    assert.equal(guestContentAllowed({ status: "trial", trialEndsAt: "2026-04-01T00:00:00Z" }, now), true);
    assert.equal(
      guestContentAllowed({ status: "past_due", graceEndsAt: "2026-03-10T00:00:00Z" }, now),
      true,
    );
    assert.equal(
      guestContentAllowed({ status: "past_due", graceEndsAt: "2026-03-09T23:59:59Z" }, now),
      false,
    );
    assert.equal(
      guestContentAllowed({
        status: "canceled",
        currentPeriodEndsAt: "2026-02-24T00:00:00Z",
        graceDays: 14,
      }, now),
      true,
    );
    assert.equal(
      guestContentAllowed({
        status: "canceled",
        currentPeriodEndsAt: "2026-02-23T00:00:00Z",
        graceDays: 14,
      }, now),
      false,
    );
  });
});
