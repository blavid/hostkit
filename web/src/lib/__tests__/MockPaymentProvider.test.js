import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { MockPaymentProvider, PLAN } from "../MockPaymentProvider.js";

describe("MockPaymentProvider", () => {
  it("starts a 30-day trial", async () => {
    const t0 = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => t0 });
    const sub = await p.startTrial("host-1");
    assert.equal(sub.status, "trial");
    assert.equal(sub.graceDays, 14);
    assert.equal(sub.trialEndsAt, "2026-01-31T00:00:00.000Z");
  });

  it("has exactly one plan: 30-day trial, then $5/mo per property", () => {
    assert.equal(PLAN.priceUsd, 5);
    assert.equal(PLAN.interval, "month");
    assert.equal(PLAN.per, "property");
    assert.equal(PLAN.trialDays, 30);
    assert.equal(PLAN.label, "30-day free trial, then $5/mo per property");
  });

  it("subscribes to the single plan and rejects any other", async () => {
    const t0 = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => t0 });
    const trial = await p.startTrial("h");
    assert.equal(trial.plan, PLAN.id);
    const sub = await p.subscribe("h");
    assert.equal(sub.status, "active");
    assert.equal(sub.plan, PLAN.id);
    assert.equal(sub.currentPeriodEndsAt, "2026-01-31T00:00:00.000Z");
    await assert.rejects(() => p.subscribe("h", "annual"), /invalid plan/);
  });

  it("adopts a trial started at signup without restarting it", async () => {
    const t0 = Date.parse("2026-01-10T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => t0 });
    const record = { startedAt: "2026-01-01T00:00:00.000Z", trialEndsAt: "2026-01-31T00:00:00.000Z" };
    const sub = await p.adoptTrial("h", record);
    assert.equal(sub.status, "trial");
    assert.equal(sub.plan, PLAN.id);
    assert.equal(sub.trialEndsAt, record.trialEndsAt);
    await assert.rejects(() => p.adoptTrial("h2", { trialEndsAt: "nope" }), /invalid trial/);
  });

  it("cancel → past_due with 14-day grace, then canceled", async () => {
    let now = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => now });
    await p.startTrial("h");
    await p.subscribe("h");
    const canceled = await p.cancel("h");
    assert.equal(canceled.status, "past_due");
    assert.ok(canceled.graceEndsAt);

    now = Date.parse(canceled.graceEndsAt) + 1000;
    const after = await p.getStatus("h");
    assert.equal(after.status, "canceled");
  });

  it("lapsing trial enters grace", async () => {
    let now = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => now });
    const trial = await p.startTrial("h", 1);
    now = Date.parse(trial.trialEndsAt) + 1000;
    const status = await p.getStatus("h");
    assert.equal(status.status, "past_due");
    assert.ok(status.graceEndsAt);
  });

  it("toSchemaSubscription strips private fields", async () => {
    const p = new MockPaymentProvider();
    const sub = await p.startTrial("h");
    const coarse = p.toSchemaSubscription(sub);
    assert.equal(coarse.status, "trial");
    assert.equal(coarse.graceDays, 14);
    assert.equal("hostId" in coarse, false);
  });
});
