import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { catchAnthropicFailure } from "../../../durable-object/anthropic/catch-anthropic-failure";
import type { ClassificationResult } from "../../domain/conversation-provider";
import { ConversationProviderError } from "../../domain/conversation-provider-error";
import { createHaikuClassificationRequest } from "./create-haiku-classification-request";
import { readHaikuClassification } from "./read-haiku-classification";

// 読み分けの呼び出し1回の時間の上限。アラームは文章を1つずつ読むので、止まった呼び出しが後ろの文章と推定を待たせないよう、
// 短い判断に見合う長さにする（自分で決めた値）
const classificationTimeLimitMs = 30_000;

// Haiku 5.5 に読み分けさせる。失敗はどれも会話になるので、種類（errorType）で分けるだけにし、応答のエラーを cause に持たせる。
// 時間切れは timed_out。応答の中身（モデルの答えのテキスト）は残さない
export const classifyWithHaiku = (
  client: Anthropic,
  userId: string,
  body: string,
): R.ResultAsync<ClassificationResult, ConversationProviderError> =>
  R.pipe(
    catchAnthropicFailure(
      client.messages.create(
        { ...createHaikuClassificationRequest(body), metadata: { user_id: userId } },
        { timeout: classificationTimeLimitMs },
      ),
      (failure) =>
        new ConversationProviderError({
          errorType: match(failure)
            .with({ type: "timed_out" }, () => "timed_out")
            .with({ type: "bad_request" }, { type: "provider_error" }, ({ errorType }) => errorType)
            .exhaustive(),
          cause: failure.cause,
        }),
    ),
    R.andThen(readHaikuClassification),
  );
