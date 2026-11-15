/**
 * Pages may serve a copied index.html at /wizard/ or /wizard/index.html.
 * Normalize so BrowserRouter's /wizard route matches after a deep link or refresh.
 */
export function normalizePreviewPathname(pathname) {
  let next = String(pathname || "/");
  if (next.endsWith("/index.html")) {
    next = next.slice(0, -"/index.html".length);
  }
  if (next.length > 1 && next.endsWith("/")) {
    next = next.slice(0, -1);
  }
  if (!next.startsWith("/")) next = `/${next}`;
  return next || "/";
}

export function applyPreviewPathNormalization(loc = window.location, hist = window.history) {
  const next = normalizePreviewPathname(loc.pathname);
  if (next !== loc.pathname) {
    hist.replaceState(hist.state, "", `${next}${loc.search || ""}${loc.hash || ""}`);
    return next;
  }
  return loc.pathname;
}

const LEGACY_PREFIX = "/hostkit-preview";

/** Path without the old /hostkit-preview prefix, or null when there is none. */
export function legacyPreviewPath(pathname) {
  const path = String(pathname || "/");
  if (path !== LEGACY_PREFIX && !path.startsWith(`${LEGACY_PREFIX}/`)) return null;
  return path.slice(LEGACY_PREFIX.length) || "/";
}
