import {
  APIConnectionError,
  APIConnectionTimeoutError,
  APIError,
  APIUserAbortError,
  BadRequestError,
} from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { LlmCallBadRequestError } from "../../domain/llm-call-bad-request-error";
import { LlmCallError } from "../../domain/llm-call-error";
import { LlmCallTimedOutError } from "../../domain/llm-call-timed-out-error";

// Anthropic の API の呼び出しを Result にする。SDK が投げる提供元の失敗を LLM の呼び出しの失敗に写し、SDK の失敗でないもの（想定外）は投げ直す。
// Anthropic の失敗を写すのはここだけにする（推定・読み分け・返事の呼び出しがどれもここを通る）
export const catchAnthropicFailure = <T>(
  call: Promise<T>,
): R.ResultAsync<T, LlmCallError | LlmCallBadRequestError | LlmCallTimedOutError> =>
  call.then(
    (value) => R.succeed(value),
    (error: unknown) => {
      const failure = toLlmCallFailure(error);
      if (failure === undefined) {
        throw error;
      }
      return R.fail(failure);
    },
  );

// errorType は提供元のエラーの種類（応答に無ければ HTTP の状態コード、つなげなかったときは connection_error）。
// 流している途中のエラーの出来事は、状態コードの無い APIError で届く
const toLlmCallFailure = (
  error: unknown,
): LlmCallError | LlmCallBadRequestError | LlmCallTimedOutError | undefined => {
  // 時間の上限（呼び出し1回の timeout と、試み全体の signal）
  if (error instanceof APIConnectionTimeoutError || error instanceof APIUserAbortError) {
    return new LlmCallTimedOutError({ cause: error });
  }
  // 400 は状態コードで見分ける（月の支出の上限に当たったときも 400。メッセージの文字列では見分けない）
  if (error instanceof BadRequestError) {
    return new LlmCallBadRequestError({ errorType: error.type ?? "http_400", cause: error });
  }
  if (error instanceof APIConnectionError) {
    return new LlmCallError({ errorType: "connection_error", cause: error });
  }
  if (error instanceof APIError) {
    return new LlmCallError({ errorType: error.type ?? `http_${error.status}`, cause: error });
  }
  return undefined;
};
