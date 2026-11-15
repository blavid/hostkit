import test from "node:test";
import assert from "node:assert/strict";
import {
  normalizeCode,
  validateSignup,
  buildTrialRecord,
  wizardHref,
  saveTrial,
  loadTrial,
  TRIAL_KEY,
} from "../../../sales-site/assets/trial.js";

function memoryStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), _m: m };
}

test("normalizeCode accepts the pairing alphabet only", () => {
  assert.equal(normalizeCode(" abc234 "), "ABC234");
  assert.equal(normalizeCode("abc-234"), "ABC234");
  assert.equal(normalizeCode("OOL111"), "");
  assert.equal(normalizeCode("ABC23"), "");
  assert.equal(normalizeCode(null), "");
});

test("validateSignup requires a name and a plausible email", () => {
  assert.deepEqual(validateSignup({ name: "Test Host", email: "host@example.invalid" }), { ok: true, errors: {} });
  const bad = validateSignup({ name: " ", email: "nope" });
  assert.equal(bad.ok, false);
  assert.ok(bad.errors.name);
  assert.ok(bad.errors.email);
});

test("trial record is a mock 30-day trial with the code and no payment fields", () => {
  const now = Date.parse("2026-11-15T00:00:00Z");
  const rec = buildTrialRecord({ name: " Test Host ", email: "host@example.invalid", code: "abc234" }, now);
  assert.equal(rec.mock, true);
  assert.equal(rec.name, "Test Host");
  assert.equal(rec.code, "ABC234");
  assert.equal(rec.trialEndsAt, "2026-12-15T00:00:00.000Z");
  assert.deepEqual(Object.keys(rec).sort(), ["code", "email", "mock", "name", "startedAt", "trialEndsAt"]);
});

test("wizardHref carries a valid code and drops an invalid one", () => {
  assert.equal(wizardHref("ABC234"), "wizard/?code=ABC234");
  assert.equal(wizardHref("OOL111"), "wizard/");
  assert.equal(wizardHref(""), "wizard/");
});

test("trial round-trips through storage and ignores junk", () => {
  const s = memoryStorage();
  assert.equal(loadTrial(s), null);
  saveTrial(s, buildTrialRecord({ name: "A", email: "a@example.invalid", code: "ABC234" }));
  assert.equal(loadTrial(s).code, "ABC234");
  s.setItem(TRIAL_KEY, "{not json");
  assert.equal(loadTrial(s), null);
});
