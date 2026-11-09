/**
 * Pairing codes: 6 characters. Alphabet excludes 0, O, 1, I, and L (SPEC §4, Rocky M3).
 */

export const CODE_ALPHABET = "ABCDEFGH" + "JKMNPQRS" + "TUVWXYZ" + "23456789";
export const CODE_LENGTH = 6;

export function normalizePairCode(input) {
  return String(input ?? "").trim().toUpperCase();
}

export function isValidPairCode(input) {
  const code = normalizePairCode(input);
  if (code.length !== CODE_LENGTH) return false;
  for (const ch of code) {
    if (!CODE_ALPHABET.includes(ch)) return false;
  }
  return true;
}

/** Prefill from ?code= or a /pair/:code path segment. */
export function codeFromLocation(search = "", pathname = "") {
  const params = new URLSearchParams(
    String(search || "").startsWith("?") ? search.slice(1) : search
  );
  const fromQuery = params.get("code");
  if (fromQuery) return normalizePairCode(fromQuery);
  const parts = String(pathname || "").split("/").filter(Boolean);
  const pairIdx = parts.findIndex((p) => p.toLowerCase() === "pair");
  if (pairIdx >= 0 && parts[pairIdx + 1]) {
    return normalizePairCode(parts[pairIdx + 1].replace(/\.html$/i, ""));
  }
  return "";
}
