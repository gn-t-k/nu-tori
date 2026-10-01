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

const estimationTimeoutMs = 3 * 60 * 1000;
const pollIntervalMs = 5000;

try {
  await runMainFlow({
    baseUrl,
    signInSecret,
    photo: await readFile(join(import.meta.dirname, "photos", "oyakodon.jpg")),
    send: (url, init) => fetch(url, init),
    estimationTimeoutMs,
    pollIntervalMs,
    log: (message) => console.log(message),
  });
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}
