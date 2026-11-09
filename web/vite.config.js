import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { mkdirSync, copyFileSync, readFileSync, writeFileSync, existsSync } from "node:fs";
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

export default defineConfig({
  plugins: [react(), spaFallbacks()],
  base: "/hostkit-preview/",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  publicDir: "public",
});
