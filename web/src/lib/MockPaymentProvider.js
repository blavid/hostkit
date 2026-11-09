/**
 * Swappable payment interface — mock only. No cards, no charges, no SDK.
 * SPEC §10.5
 */

const DAY_MS = 24 * 60 * 60 * 1000;
const GRACE_DAYS = 14;

function iso(d) {
  return new Date(d).toISOString();
}

export class MockPaymentProvider {
  constructor({ now = () => Date.now(), store = new Map() } = {}) {
    this.now = now;
    this.store = store;
  }

  async startTrial(hostId, days = 30) {
    const start = this.now();
    const sub = {
      hostId,
      status: "trial",
      plan: "monthly",
      trialEndsAt: iso(start + days * DAY_MS),
      graceDays: GRACE_DAYS,
      currentPeriodEndsAt: iso(start + days * DAY_MS),
    };
    this.store.set(hostId, sub);
    return { ...sub };
  }

  async subscribe(hostId, plan) {
    if (plan !== "monthly" && plan !== "annual") {
      throw new Error(`invalid plan: ${plan}`);
    }
    const existing = this.store.get(hostId) || {};
    const start = this.now();
    const periodDays = plan === "annual" ? 365 : 30;
    const sub = {
      ...existing,
      hostId,
      status: "active",
      plan,
      trialEndsAt: existing.trialEndsAt,
      graceDays: GRACE_DAYS,
      currentPeriodEndsAt: iso(start + periodDays * DAY_MS),
      graceEndsAt: undefined,
    };
    delete sub.graceEndsAt;
    this.store.set(hostId, sub);
    return { ...sub };
  }

  async cancel(hostId) {
    const existing = this.store.get(hostId);
    if (!existing) throw new Error(`unknown host: ${hostId}`);
    const end = this.now();
    const sub = {
      ...existing,
      status: "past_due",
      graceDays: GRACE_DAYS,
      graceEndsAt: iso(end + GRACE_DAYS * DAY_MS),
    };
    this.store.set(hostId, sub);
    return { ...sub };
  }

  async getStatus(hostId) {
    const existing = this.store.get(hostId);
    if (!existing) throw new Error(`unknown host: ${hostId}`);
    const now = this.now();
    let sub = { ...existing };

    // Auto-lapse trial → past_due with grace
    if (
      sub.status === "trial" &&
      sub.trialEndsAt &&
      now >= Date.parse(sub.trialEndsAt)
    ) {
      sub = {
        ...sub,
        status: "past_due",
        graceEndsAt: iso(Date.parse(sub.trialEndsAt) + GRACE_DAYS * DAY_MS),
      };
      this.store.set(hostId, sub);
    }

    // Grace expired → canceled
    if (
      sub.status === "past_due" &&
      sub.graceEndsAt &&
      now >= Date.parse(sub.graceEndsAt)
    ) {
      sub = { ...sub, status: "canceled" };
      this.store.set(hostId, sub);
    }

    return { ...sub };
  }

  /** Coarse schema.subscription fields for publishing. */
  toSchemaSubscription(sub) {
    const out = {
      status: sub.status,
      plan: sub.plan,
      graceDays: sub.graceDays ?? GRACE_DAYS,
    };
    if (sub.trialEndsAt) out.trialEndsAt = sub.trialEndsAt;
    if (sub.currentPeriodEndsAt) out.currentPeriodEndsAt = sub.currentPeriodEndsAt;
    if (sub.graceEndsAt) out.graceEndsAt = sub.graceEndsAt;
    return out;
  }
}
