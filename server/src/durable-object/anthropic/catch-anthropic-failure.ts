import {
  APIConnectionError,
  APIConnectionTimeoutError,
  APIError,
  APIUserAbortError,
  BadRequestError,
} from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";

// Anthropic の API の呼び出しを Result にする。SDK が投げる提供元の失敗を種類に分けて toFailure で失敗に直し、SDK の失敗でないもの（想定外）は投げ直す
export const catchAnthropicFailure = <T, E>(
  call: Promise<T>,
  toFailure: (failure: AnthropicFailure) => E,
): R.ResultAsync<T, E> =>
  call.then(
    (value) => R.succeed(value),
    (error: unknown) => {
      const failure = classifyAnthropicFailure(error);
      if (failure === undefined) {
        throw error;
      }
      return R.fail(toFailure(failure));
    },
  );

// errorType は提供元のエラーの種類（応答に無ければ HTTP の状態コード、つなげなかったときは connection_error）
type AnthropicFailure =
  | { type: "timed_out"; cause: APIError }
  | { type: "bad_request"; errorType: string; cause: APIError }
  | { type: "provider_error"; errorType: string; cause: APIError };

// 流している途中のエラーの出来事は、状態コードの無い APIError で届く
const classifyAnthropicFailure = (error: unknown): AnthropicFailure | undefined => {
  // 時間の上限（呼び出し1回の timeout と、試み全体の signal）
  if (error instanceof APIConnectionTimeoutError || error instanceof APIUserAbortError) {
    return { type: "timed_out", cause: error };
  }
  // 400 は状態コードで見分ける（月の支出の上限に当たったときも 400。メッセージの文字列では見分けない）
  if (error instanceof BadRequestError) {
    return { type: "bad_request", errorType: error.type ?? "http_400", cause: error };
  }
  if (error instanceof APIConnectionError) {
    return { type: "provider_error", errorType: "connection_error", cause: error };
  }
  if (error instanceof APIError) {
    return {
      type: "provider_error",
      errorType: error.type ?? `http_${error.status}`,
      cause: error,
    };
  }
  return undefined;
};
