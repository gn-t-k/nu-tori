import { match } from "ts-pattern";

// 返事の生成の試み。結果の無い試みは、呼び出し中か、途中で止まった試み
export type ReplyAttempt = {
  attemptedAt: Date;
  ended: { endedAt: Date; conclusion: ReplyAttemptConclusion } | undefined;
};

// 試みの結果。提供元のエラーの種類は、提供元のエラーと 400 のときだけ持つ
export type ReplyAttemptConclusion =
  | { result: "succeeded" }
  // invalid_response は、出力の上限で切れた・読めない応答と、指し示せない食事の ID を返した応答
  | { result: "timed_out" | "invalid_response" }
  | { result: "provider_error" | "bad_request"; errorType: string };

// 試みで提供元が返したエラーの種類。提供元のエラーと 400 のときだけある
export const findProviderErrorType = (conclusion: ReplyAttemptConclusion): string | undefined =>
  match(conclusion)
    .with(
      { result: "succeeded" },
      { result: "timed_out" },
      { result: "invalid_response" },
      () => undefined,
    )
    .with({ result: "provider_error" }, { result: "bad_request" }, ({ errorType }) => errorType)
    .exhaustive();
