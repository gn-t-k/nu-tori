import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { runMainFlow } from "./run-main-flow";

// 開発用の環境へデプロイしたあとに、GitHub Actions（.github/workflows/deploy.yml）が回す。
// 本物の API と本物の推定の提供元を通すので、コードのテストとは別に置く。
// E2E_BASE_URL: 確かめる Worker の URL（開発用）、E2E_SIGN_IN_SECRET: サインインの口の秘密の値
const baseUrl = process.env["E2E_BASE_URL"];
const signInSecret = process.env["E2E_SIGN_IN_SECRET"];
if (baseUrl === undefined || baseUrl === "" || signInSecret === undefined || signInSecret === "") {
  console.error("E2E_BASE_URL と E2E_SIGN_IN_SECRET を環境変数で渡す");
  process.exit(2);
}

// 待つ時間の上限。写真の推定と文章の食事の推定（読み分けを含む）で 3 分ずつ、返事（読み分けと返事）で 2 分。
// どれも上限まで待つと 8 分になり、ジョブの準備と合わせて deploy.yml の timeout-minutes に収める
const estimationTimeoutMs = 3 * 60 * 1000;
const replyTimeoutMs = 2 * 60 * 1000;
const pollIntervalMs = 5000;

try {
  await runMainFlow({
    baseUrl,
    signInSecret,
    photo: await readFile(join(import.meta.dirname, "photos", "oyakodon.jpg")),
    send: (url, init) => fetch(url, init),
    estimationTimeoutMs,
    replyTimeoutMs,
    pollIntervalMs,
    log: (message) => console.log(message),
  });
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}
