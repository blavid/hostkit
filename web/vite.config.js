import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { mkdirSync, copyFileSync, cpSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

// Static export under /hostkit-preview for the hidden staging path.
// Also emit an index.html per SPA route so Pages can serve deep links
// even if _redirects is not applied, and a root-level _redirects note
// is copied into the packaged preview upload.
function spaFallbacks(routes = ["wizard", "pair", "setup"]) {
  return {
    name: "hostkit-spa-fallbacks",
    closeBundle() {
      const outDir = join(process.cwd(), "dist");
      const index = join(outDir, "index.html");
      if (!existsSync(index)) return;
      for (const route of routes) {
        const dest = join(outDir, route, "index.html");
        mkdirSync(dirname(dest), { recursive: true });
        copyFileSync(index, dest);
      }
    },
  };
}

// The static sales site (web/sales-site, Pixel's design) is the preview home.
// Copy it over dist/ after the SPA route fallbacks are written, so
// /hostkit-preview/ is the sales home and /wizard/, /setup/, /pair/ stay SPA.
function salesSite() {
  return {
    name: "hostkit-sales-site",
    closeBundle() {
      const outDir = join(process.cwd(), "dist");
      const src = join(process.cwd(), "sales-site");
      if (!existsSync(join(outDir, "wizard", "index.html"))) {
        throw new Error("SPA fallbacks must be written before the sales site");
      }
      cpSync(src, outDir, { recursive: true });
    },
  };
}

export default defineConfig({
  plugins: [react(), spaFallbacks(), salesSite()],
  base: "/hostkit-preview/",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  publicDir: "public",
});
