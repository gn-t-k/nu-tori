import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { exportPKCS8, generateKeyPair } from "jose";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  const secrets = {
    BETTER_AUTH_SECRET: "test-better-auth-secret-0123456789abcdef",
    APPLE_TEAM_ID: "TEAM000000",
    APPLE_KEY_ID: "KEY0000000",
    APPLE_PRIVATE_KEY: await generateApplePrivateKey(),
    APPLE_REFRESH_TOKEN_KEYS: `1:${btoa(String.fromCharCode(...new Uint8Array(32).fill(1)))}`,
    // 古い版の鍵で残したハッシュにも当たるかを確かめるため、版を2つ並べる
    APPLE_SUB_HASH_KEYS: `1:${btoa(String.fromCharCode(...new Uint8Array(32).fill(2)))},2:${btoa(String.fromCharCode(...new Uint8Array(32).fill(3)))}`,
    // DSN が空なら Sentry は送らない
    SENTRY_DSN: "",
    // 提供元（Anthropic）はテストで偽物に差し替え、本物には届かない
    ANTHROPIC_API_KEY: "test-anthropic-api-key",
  };
  // wrangler は wrangler.jsonc の secrets.required を process.env から探し、無いとテストのファイルごとに警告を出す（#794）
  Object.assign(process.env, secrets);

  return {
    plugins: [
      // テストのファイルごとに、読み込むモジュールを Workers の環境へ送り直す。依存のソースマップは送る量の大半を占めるが、落ちたテストの場所を指すのに使わないので落とす（#794）
      {
        name: "drop-dependency-sourcemaps",
        enforce: "post",
        transform: (code: string, id: string) => {
          if (id.includes("/node_modules/")) return { code, map: { mappings: "" } };
          return undefined;
        },
      },
      cloudflareTest(async () => ({
        wrangler: { configPath: "./wrangler.jsonc" },
        miniflare: {
          bindings: {
            D1_MIGRATIONS: await readD1Migrations("./d1-migrations"),
            ...secrets,
            // 課金を入れた日。開発用の設定の値に左右されず、無料体験の最後の日を決めた値で確かめるため
            BILLING_STARTED_ON: "2026-01-01",
          },
        },
      })),
    ],
    test: {
      restoreMocks: true,
      // 依存を前もって束ね、テストのファイルごとに送り直すモジュールの数を減らす（#794）
      deps: {
        optimizer: {
          ssr: {
            enabled: true,
            // 束ねるのは名前を挙げた依存だけなので、テストとコードが import する依存を集めて渡す
            include: listRuntimeBareSpecifiers(["src", "test"]),
            // Workers の環境が持つモジュールは束ねずに残す
            rolldownOptions: { external: [workersRuntimeModule] },
          },
        },
      },
      setupFiles: ["./test/apply-d1-migrations.ts", "./test/extend-result-matchers.ts"],
    },
  };
});

// 秘密の鍵をリポジトリに置かないよう、テストを回すたびに作る
const generateApplePrivateKey = async (): Promise<string> => {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
};

const workersRuntimeModule = /^(node|cloudflare):/;

// 型だけの import は Workers の環境で読まないので、束ねる依存に入れない
const listRuntimeBareSpecifiers = (directories: string[]): string[] => {
  const specifiers = new Set<string>();
  for (const directory of directories) {
    for (const file of readdirSync(directory, { recursive: true, encoding: "utf8" })) {
      if (!file.endsWith(".ts")) continue;
      const source = readFileSync(join(directory, file), "utf8");
      for (const [, fromSpecifier, sideEffectSpecifier] of source.matchAll(
        /^(?:import|export)(?!\s+type\b)[^;]*?\bfrom\s+"([^".][^"]*)"|^import\s+"([^".][^"]*)"/gm,
      )) {
        const specifier = fromSpecifier ?? sideEffectSpecifier;
        if (specifier !== undefined && !workersRuntimeModule.test(specifier))
          specifiers.add(specifier);
      }
    }
  }
  return [...specifiers];
};
