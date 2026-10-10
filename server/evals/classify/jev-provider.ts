import type { ApiProvider, ProviderResponse } from "promptfoo";
import { z } from "zod";
import { createJevClassificationInput } from "./create-jev-classification-input";
import { jevClassificationResponseSchema } from "./jev-classification-response-schema";
import type { ClassificationEvalOutput } from "./classification-eval-output";

// promptfoo の custom provider。Jev（typesafe/jev）を、開発用の AI Gateway を通る Cloudflare の REST（/ai/run）で呼ぶ。
// Node には Workers の env.AI が無いので REST にした。基準の文面はサーバーと同じものを import する。
// 鍵: NU_TORI_CLOUDFLARE_ACCOUNT_ID と、Workers AI の Read と AI Gateway の Run を持つ開発用のトークン NU_TORI_CLOUDFLARE_AI_TOKEN
export default class JevProvider implements ApiProvider {
  id = (): string => "typesafe/jev";

  callApi = async (prompt: string): Promise<ProviderResponse> => {
    const accountId = process.env["NU_TORI_CLOUDFLARE_ACCOUNT_ID"];
    const token = process.env["NU_TORI_CLOUDFLARE_AI_TOKEN"];
    if (accountId === undefined || token === undefined) {
      return {
        error: "NU_TORI_CLOUDFLARE_ACCOUNT_ID と NU_TORI_CLOUDFLARE_AI_TOKEN を置いてから回す",
      };
    }
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          // ゲートウェイを名指さないと、ログがオンの default のゲートウェイができる（#422）
          "cf-aig-gateway-id": developmentGatewayId,
          // 開発用のゲートウェイは認証がオン（#422）。同じトークンに AI Gateway の Run を持たせて通す
          "cf-aig-authorization": `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: "typesafe/jev",
          input: createJevClassificationInput(prompt),
        }),
      },
    );
    if (!response.ok) {
      return { error: `Jev の呼び出しが HTTP ${response.status} で失敗した` };
    }
    const parsedEnvelope = envelopeSchema.safeParse(await response.json());
    if (!parsedEnvelope.success) {
      return { error: "Jev の応答を読めなかった" };
    }
    const { state, result } = parsedEnvelope.data.result;
    if (state !== "Completed") {
      return { error: `Jev の実行が完了しなかった（${state}）` };
    }
    const parsedResponse = jevClassificationResponseSchema.safeParse(result);
    if (!parsedResponse.success) {
      return { error: "Jev の答えを読めなかった" };
    }
    const { answers, usage } = parsedResponse.data;
    const output: ClassificationEvalOutput = {
      kind: "probability",
      mealProbability: answers.is_meal.noul,
    };
    return {
      output,
      tokenUsage: {
        prompt: usage.input_tokens,
        completion: usage.output_tokens,
        total: usage.input_tokens + usage.output_tokens,
      },
    };
  };
}

const developmentGatewayId = "nu-tori-development";

// Cloudflare の REST は状態（state）と答えを result に包む。完了しなかった実行を形の違いと分けて知らせるため、state を先に見る
const envelopeSchema = z.object({ result: z.object({ state: z.string(), result: z.unknown() }) });
