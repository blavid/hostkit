/**
 * Reject HTML in plain-text HostKit fields (FAQ q/a, descriptions, etc.).
 * URLs are allowed; tags and entities that look like markup are not.
 */

const TAG_RE = /<\/?[a-zA-Z][^>]*>/;
const ENTITY_RE = /&(?:#\d+|#x[0-9a-fA-F]+|[a-zA-Z]+);/;

export function looksLikeHtml(value) {
  if (typeof value !== "string") return false;
  return TAG_RE.test(value) || ENTITY_RE.test(value);
}

/**
 * Walk a HostKit document and collect paths that contain HTML-like text.
 */
export function lintDocumentForHtml(doc) {
  const findings = [];

  function visit(value, path) {
    if (typeof value === "string") {
      if (looksLikeHtml(value)) {
        findings.push({ path, snippet: value.slice(0, 80) });
      }
      return;
    }
    if (Array.isArray(value)) {
      value.forEach((v, i) => visit(v, `${path}[${i}]`));
      return;
    }
    if (value && typeof value === "object") {
      for (const [k, v] of Object.entries(value)) {
        // Skip URL-ish keys — still lint values that contain tags
        visit(v, path ? `${path}.${k}` : k);
      }
    }
  }

  visit(doc, "");
  return { ok: findings.length === 0, findings };
}
