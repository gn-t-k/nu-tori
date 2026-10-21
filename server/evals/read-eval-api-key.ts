import { spawnSync } from "node:child_process";

// 評価の鍵は、開発用のワークスペース（nu-tori-development）のキー。ANTHROPIC_API_KEY はクラウドのセッションでエージェント自身が使う名前なので避ける。
// クラウドでは環境変数に置く。Mac では、シェルの設定に置かずに済むよう、キーチェーンからも読む
const environmentVariable = "NU_TORI_ANTHROPIC_API_KEY";
const keychainService = "nu-tori-eval";
const keychainAccount = "anthropic";

// 提供元は場面ごとに呼ぶので、キーチェーンを読むのは1回の実行で1度にする（spawnSync のあいだは並べた呼び出しが止まる）
let cached: { apiKey: string | undefined } | undefined;

export const readEvalApiKey = (): string | undefined => {
  cached ??= { apiKey: readUncached() };
  return cached.apiKey;
};

const readUncached = (): string | undefined => {
  const fromEnvironment = process.env[environmentVariable];
  if (fromEnvironment !== undefined || process.platform !== "darwin") {
    return fromEnvironment;
  }
  const keychain = spawnSync(
    "security",
    ["find-generic-password", "-s", keychainService, "-a", keychainAccount, "-w"],
    { encoding: "utf8" },
  );
  return keychain.status === 0 ? keychain.stdout.trim() : undefined;
};

export const missingEvalApiKeyMessage = `開発用のワークスペースのキーを、環境変数 ${environmentVariable} か、Mac のキーチェーン（security add-generic-password -s ${keychainService} -a ${keychainAccount} -w で置く）に置いてから回す`;
