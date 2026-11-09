import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Static export under /hostkit-preview for the hidden staging path.
export default defineConfig({
  plugins: [react()],
  base: "/hostkit-preview/",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  publicDir: "public",
});
