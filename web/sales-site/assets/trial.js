/* Mock 30-day trial signup (preview only). Name + email stay in this browser.
   No payment, no network call, no email is sent. Shared by signup.html and the wizard. */
export const TRIAL_KEY = "hostkit_trial";
export const CODE_KEY = "hostkit_tv_code";
export const TRIAL_DAYS = 30;
const CODE_RE = /^[A-HJKMNP-Z2-9]{6}$/; // 6 chars, no 0 O 1 I L
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function normalizeCode(raw) {
  const c = String(raw ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
  return CODE_RE.test(c) ? c : "";
}

export function validateSignup({ name, email } = {}) {
  const errors = {};
  const n = String(name ?? "").trim();
  const e = String(email ?? "").trim();
  if (!n) errors.name = "Enter your name.";
  else if (n.length > 100) errors.name = "Use 100 characters or fewer.";
  if (!e) errors.email = "Enter your email.";
  else if (e.length > 254 || !EMAIL_RE.test(e)) errors.email = "Enter an email like you@example.com.";
  return { ok: Object.keys(errors).length === 0, errors };
}

export function buildTrialRecord({ name, email, code } = {}, now = Date.now()) {
  return {
    mock: true,
    name: String(name).trim(),
    email: String(email).trim(),
    code: normalizeCode(code) || null,
    startedAt: new Date(now).toISOString(),
    trialEndsAt: new Date(now + TRIAL_DAYS * 864e5).toISOString(),
  };
}

/** Relative to /hostkit-preview/, so the code rides along to the wizard. */
export function wizardHref(code) {
  const c = normalizeCode(code);
  return c ? `wizard/?code=${encodeURIComponent(c)}` : "wizard/";
}

export function saveTrial(storage, record) {
  try { storage.setItem(TRIAL_KEY, JSON.stringify(record)); return true; } catch { return false; }
}

export function loadTrial(storage) {
  try {
    const r = JSON.parse(storage.getItem(TRIAL_KEY) || "null");
    return r && typeof r === "object" && r.mock === true && r.email ? r : null;
  } catch { return null; }
}
