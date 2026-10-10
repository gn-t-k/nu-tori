import type { ApiProvider, ProviderResponse } from "promptfoo";
import { z } from "zod";
import { createJevClassificationInput } from "../../src/reply/durable-object/create-conversation-provider/create-jev-classification-input";
import { jevClassificationResponseSchema } from "../../src/reply/durable-object/create-conversation-provider/jev-classification-response-schema";
import type { ClassificationEvalOutput } from "./classification-eval-output";

// promptfoo の custom provider。Jev（typesafe/jev）を、開発用の AI Gateway を通る Cloudflare の REST（/ai/run）で呼ぶ。
// Node には Workers の env.AI が無いので REST にした。指示の文面と答えの形はサーバーと同じものを import する。
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
    const parsed = envelopeSchema.safeParse(await response.json());
    if (!parsed.success) {
      return { error: "Jev の応答を読めなかった" };
    }
    const { answers, usage } = parsed.data.result;
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

// Cloudflare の REST は答えを result に包んで返す
const envelopeSchema = z.object({ result: jevClassificationResponseSchema });
