/**
 * Worker base URL comes from config, not a baked-in secret or shared token.
 * When the preview Worker is not live, the wizard shows a friendly notice.
 */

export const TV_SERVICE_NOT_LIVE = "TV service not live yet";

const DEFAULT_CONFIG = { apiBase: "" };

export function normalizeApiBase(value) {
  return String(value || "").trim().replace(/\/+$/, "");
}

export function isApiConfigured(config) {
  return Boolean(normalizeApiBase(config?.apiBase));
}

export async function loadApiConfig({ fetchImpl = fetch, href } = {}) {
  const envBase = normalizeApiBase(
    (typeof import.meta !== "undefined" && import.meta.env && import.meta.env.VITE_HOSTKIT_API_BASE) || ""
  );
  let file = { ...DEFAULT_CONFIG };
  try {
    const url = href || new URL("hostkit-config.json", document.baseURI).toString();
    const res = await fetchImpl(url, { cache: "no-store" });
    if (res.ok) {
      file = { ...file, ...(await res.json()) };
    }
  } catch {
    // Optional file — env or empty config still works.
  }
  const apiBase = envBase || normalizeApiBase(file.apiBase);
  return { apiBase, source: envBase ? "env" : file.apiBase ? "file" : "none" };
}
