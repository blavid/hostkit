/** 14-day subscription grace math (SPEC §4 / §11.1 decision 5). */

export const DEFAULT_GRACE_DAYS = 14;
export const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function graceEndsAt(lapsedAt, graceDays = DEFAULT_GRACE_DAYS) {
  const start = typeof lapsedAt === "number" ? lapsedAt : Date.parse(lapsedAt);
  if (!Number.isFinite(start)) throw new Error("invalid lapsedAt");
  const days = Number(graceDays);
  if (!Number.isFinite(days) || days < 0) throw new Error("invalid graceDays");
  return new Date(start + days * MS_PER_DAY).toISOString();
}

/**
 * Whether the TV should keep serving guest content for this subscription.
 * trial / active always serve. past_due and canceled serve through graceEndsAt
 * (computed from currentPeriodEndsAt or trialEndsAt + graceDays when missing).
 */
export function guestContentAllowed(subscription, now = Date.now()) {
  if (subscription == null || typeof subscription !== "object") return true;
  const status = subscription.status || "active";
  if (status === "trial" || status === "active") return true;
  if (status !== "past_due" && status !== "canceled") return true;
  const ends = graceDeadline(subscription);
  if (ends == null) return false;
  const ts = typeof now === "number" ? now : Date.parse(now);
  return ts <= ends;
}

export function graceDeadline(subscription) {
  if (subscription == null) return null;
  if (subscription.graceEndsAt) {
    const parsed = Date.parse(subscription.graceEndsAt);
    return Number.isFinite(parsed) ? parsed : null;
  }
  const lapsedAt = subscription.currentPeriodEndsAt || subscription.trialEndsAt;
  if (!lapsedAt) return null;
  const days = subscription.graceDays == null ? DEFAULT_GRACE_DAYS : Number(subscription.graceDays);
  return Date.parse(graceEndsAt(lapsedAt, days));
}
