import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { MockPaymentProvider } from "../MockPaymentProvider.js";

describe("MockPaymentProvider", () => {
  it("starts a 30-day trial", async () => {
    const t0 = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => t0 });
    const sub = await p.startTrial("host-1");
    assert.equal(sub.status, "trial");
    assert.equal(sub.graceDays, 14);
    assert.equal(sub.trialEndsAt, "2026-01-31T00:00:00.000Z");
  });

  it("subscribes monthly or annual", async () => {
    const t0 = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => t0 });
    await p.startTrial("h");
    const monthly = await p.subscribe("h", "monthly");
    assert.equal(monthly.status, "active");
    assert.equal(monthly.plan, "monthly");
    const annual = await p.subscribe("h", "annual");
    assert.equal(annual.plan, "annual");
  });

  it("cancel → past_due with 14-day grace, then canceled", async () => {
    let now = Date.parse("2026-01-01T00:00:00Z");
    const p = new MockPaymentProvider({ now: () => now });
    await p.startTrial("h");
    await p.subscribe("h", "monthly");
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
