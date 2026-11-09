/** Pairing codes: 6 characters, no 0 / O / 1 / I (SPEC §4). */

export const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 6;
export const PAIR_TTL_MS = 15 * 60 * 1000;
export const POLL_AFTER_MS = 5000;

const FORBIDDEN = new Set(["0", "O", "1", "I"]);

export function isValidCode(code) {
  if (typeof code !== "string" || code.length !== CODE_LENGTH) return false;
  const upper = code.toUpperCase();
  for (const ch of upper) {
    if (FORBIDDEN.has(ch)) return false;
    if (!CODE_ALPHABET.includes(ch)) return false;
  }
  return true;
}

export function makeCode(randomBytes = defaultRandom) {
  const bytes = randomBytes(CODE_LENGTH);
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  if (!isValidCode(out)) throw new Error("generated invalid pairing code");
  return out;
}

function defaultRandom(n) {
  const bytes = new Uint8Array(n);
  crypto.getRandomValues(bytes);
  return bytes;
}

export function newExpiresAt(now, ttlMs = PAIR_TTL_MS) {
  return new Date(now + ttlMs).toISOString();
}

export function isExpired(expiresAt, now) {
  const ts = Date.parse(expiresAt);
  if (!Number.isFinite(ts)) return true;
  return now >= ts;
}
