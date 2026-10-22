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

// --mode test は、本番のページにテストだけの LP の版を足して、本番の dist と別の場所に書き出す（vitest.config.ts の、版を2つにした Worker が読む）
export default defineConfig(({ mode }) => ({
  build: { outDir: mode === "test" ? ".wrangler/test-dist" : "dist", emptyOutDir: true },
  plugins: [
    ssg({ entry: mode === "test" ? "./src/testing/test-site-app.tsx" : "./src/site-app.tsx" }),
    writeHeadersFile(),
  ],
}));
