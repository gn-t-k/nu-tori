import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-pool-workers";
import { exportPKCS8, generateKeyPair } from "jose";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest(async () => ({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          D1_MIGRATIONS: await readD1Migrations("./d1-migrations"),
          BETTER_AUTH_SECRET: "test-better-auth-secret-0123456789abcdef",
          APPLE_TEAM_ID: "TEAM000000",
          APPLE_KEY_ID: "KEY0000000",
          APPLE_PRIVATE_KEY: await generateApplePrivateKey(),
          APPLE_REFRESH_TOKEN_KEYS: `1:${btoa(String.fromCharCode(...new Uint8Array(32).fill(1)))}`,
        },
      },
    })),
  ],
  test: {
    restoreMocks: true,
    setupFiles: ["./test/apply-d1-migrations.ts"],
  },
});

// 秘密の鍵をリポジトリに置かないよう、テストを回すたびに作る
const generateApplePrivateKey = async (): Promise<string> => {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
};
