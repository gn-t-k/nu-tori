import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { runMainFlow } from "../run-main-flow";

// 主な流れを、渡した URL の Worker に通す入口。Node で pnpm exec tsx e2e/cli/run-main-flow.ts と動かす。
// 開発用の環境へデプロイしたあとに GitHub Actions（.github/workflows/deploy.yml）が回し、手元の確かめ（verify-server）が wrangler dev に向けて回す。
// 本物の API と、Worker に置いた推定の提供元を通すので、コードのテストとは別に置く。
// E2E_BASE_URL: 確かめる Worker の URL、E2E_SIGN_IN_SECRET: その Worker のサインインの口の秘密の値
// E2E_ESTIMATION_TIMEOUT_SECONDS・E2E_REPLY_TIMEOUT_SECONDS: 推定と返事を待つ上限（省けば 180 秒と 120 秒）
const baseUrl = process.env["E2E_BASE_URL"];
const signInSecret = process.env["E2E_SIGN_IN_SECRET"];
if (baseUrl === undefined || baseUrl === "" || signInSecret === undefined || signInSecret === "") {
  console.error("E2E_BASE_URL と E2E_SIGN_IN_SECRET を環境変数で渡す");
  process.exit(2);
}

const readSeconds = (name: string, fallback: number): number => {
  const value = process.env[name];
  if (value === undefined || value === "") {
    return fallback;
  }
  const seconds = Number(value);
  if (!Number.isInteger(seconds) || seconds <= 0) {
    console.error(`${name} は正の整数の秒で渡す（${value}）`);
    process.exit(2);
  }
  return seconds;
};

try {
  await runMainFlow({
    baseUrl,
    signInSecret,
    photo: await readFile(join(import.meta.dirname, "..", "photos", "oyakodon.jpg")),
    send: (url, init) => fetch(url, init),
    estimationTimeoutMs: readSeconds("E2E_ESTIMATION_TIMEOUT_SECONDS", 180) * 1000,
    replyTimeoutMs: readSeconds("E2E_REPLY_TIMEOUT_SECONDS", 120) * 1000,
    pollIntervalMs: 5000,
    log: (message) => console.log(message),
  });
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}
