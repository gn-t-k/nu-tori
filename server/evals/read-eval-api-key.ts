import { spawnSync } from "node:child_process";

// 評価の鍵は、開発用のワークスペース（nu-tori-development）のキー。ANTHROPIC_API_KEY はクラウドのセッションでエージェント自身が使う名前なので避ける。
// クラウドでは環境変数に置く。Mac では、シェルの設定に置かずに済むよう、キーチェーンからも読む
export const readEvalApiKey = (): string | undefined => {
  const fromEnvironment = process.env["NU_TORI_ANTHROPIC_API_KEY"];
  if (fromEnvironment !== undefined || process.platform !== "darwin") {
    return fromEnvironment;
  }
  const keychain = spawnSync(
    "security",
    ["find-generic-password", "-s", "nu-tori-eval", "-a", "anthropic", "-w"],
    { encoding: "utf8" },
  );
  return keychain.status === 0 ? keychain.stdout.trim() : undefined;
};

export const missingEvalApiKeyMessage =
  "開発用のワークスペースのキーを、環境変数 NU_TORI_ANTHROPIC_API_KEY か、Mac のキーチェーン（security add-generic-password -s nu-tori-eval -a anthropic -w で置く）に置いてから回す";
