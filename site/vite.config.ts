import ssg from "@hono/vite-ssg";
import { defineConfig, type Plugin } from "vite";
import { securityHeaders } from "./src/security-headers.ts";

// Worker を通らない静的な asset に、Worker と同じセキュリティのヘッダーを付ける
const writeHeadersFile = (): Plugin => ({
  name: "nu-tori-headers-file",
  apply: "build",
  generateBundle() {
    const lines = Object.entries(securityHeaders).map(([name, value]) => `  ${name}: ${value}`);
    this.emitFile({ type: "asset", fileName: "_headers", source: ["/*", ...lines, ""].join("\n") });
  },
});

export default defineConfig({
  build: { outDir: "dist", emptyOutDir: true },
  plugins: [ssg({ entry: "./src/site-app.tsx" }), writeHeadersFile()],
});
