#!/usr/bin/env node
/**
 * Assemble the Pages upload tree. The site is served at the root on both
 * host-kit.com and hostkit-preview.pages.dev:
 *   <out>/index.html          — static sales home (web/sales-site). Pages also serves it
 *                               for unknown paths; its inline script forwards old
 *                               /hostkit-preview/* links and /pair/:code.
 *   <out>/wizard|setup|pair/  — SPA shell
 *   <out>/_headers, _redirects — send both as deployment form fields, not only as assets
 *   <out>/robots.txt, hostkit-config.json
 *
 * HOSTKIT_API_BASE=<url> overrides apiBase in hostkit-config.json (default
 * https://api.host-kit.com from public/).
 */
import { cpSync, mkdirSync, writeFileSync, rmSync, existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const dist = join(webRoot, "dist");
const out = process.argv[2] || join(webRoot, "..", "..", "hostkit-preview-upload");

for (const f of ["index.html", "wizard/index.html", "_headers", "_redirects", "robots.txt", "hostkit-config.json"]) {
  if (!existsSync(join(dist, f))) throw new Error(`web/dist/${f} is missing — run npm run build first`);
}
if (!readFileSync(join(dist, "_headers"), "utf8").includes("X-Robots-Tag: noindex")) {
  throw new Error("_headers must keep X-Robots-Tag: noindex");
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync(dist, out, { recursive: true });

const apiBase = String(process.env.HOSTKIT_API_BASE || "").trim().replace(/\/+$/, "");
if (apiBase) {
  if (!/^https:\/\/[^/]+$/.test(apiBase)) throw new Error("HOSTKIT_API_BASE must be an https origin");
  writeFileSync(join(out, "hostkit-config.json"), JSON.stringify({ apiBase }, null, 2) + "\n");
}

console.log(`packed upload at ${out}`);
