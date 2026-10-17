import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { checkEvalKey } from "./check-eval-key";
import { describeLlmCallFailure } from "./describe-llm-call-failure";

// 評価の鍵 NU_TORI_ANTHROPIC_API_KEY で呼べるかを、場面を回す前に確かめ、呼べなければ理由を出して止める（#565）。
// 鍵は開発用のワークスペース（nu-tori-development）のキー。ANTHROPIC_API_KEY はクラウドのセッションでエージェント自身が使う名前なので避ける
export const exitIfEvalKeyFails = async (): Promise<void> => {
  const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
  if (apiKey === undefined) {
    exitWith("開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す");
  }
  // 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
  const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com", maxRetries: 0 });
  const checked = await checkEvalKey(client);
  if (R.isFailure(checked)) {
    exitWith(
      [
        `評価の鍵で呼べなかったので、場面を回さずに止めた: ${describeLlmCallFailure(checked.error)}`,
        // 月の支出の上限に達したときも 400 になる
        ...(checked.error.name === "LlmCallBadRequestError"
          ? [
              "開発用のワークスペースの月の支出の上限に達していないかを、Anthropic の Console で確かめる",
            ]
          : []),
      ].join("\n"),
    );
  }
};

const exitWith = (message: string): never => {
  console.error(message);
  process.exit(1);
};
