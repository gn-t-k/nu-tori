import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { SentText } from "../../sent-text/domain/sent-text";
import { assembleReplyContext } from "./assemble-reply-context";
import type { ConversationProvider, GeneratedReply } from "./conversation-provider";
import { listReferableMealIds } from "./list-referable-meal-ids";
import { readReplyContextSource } from "./read-reply-context-source";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";
import { replyAttemptTimeLimitMs } from "./reply-attempt-time-limit-ms";
import type { ReplyContext } from "./reply-context";

// 試み1回分。応える文章の文脈を置き場から読んで組み立て、提供元に返事を作らせ、応答を確かめる。
// 文脈は呼ぶ直前に読むので、同じアラームで先に作った返事も窓に入る。
// 提供元の失敗と、確かめに通らない応答（空の返事、指し示せない食事の ID）は、失敗の試みの結果として返す。
// onText には、提供元が返す本文のできた分をそのまま渡す
export const runReplyAttempt = (
  provider: ConversationProvider,
  stores: Parameters<typeof readReplyContextSource>[0],
  sentText: SentText,
  onText: (text: string) => void,
): R.ResultAsync<SucceededOutcome, FailedOutcome> => {
  const context = assembleReplyContext(readReplyContextSource(stores, sentText, new Date()));
  return R.pipe(
    provider.generateReply({ context, onText }, AbortSignal.timeout(replyAttemptTimeLimitMs)),
    R.mapError(toFailedOutcome),
    R.andThen((generated) =>
      isValidReply(generated, context, stores)
        ? R.succeed(generated)
        : R.fail<FailedOutcome>({ result: "invalid_response", usage: generated.usage }),
    ),
    R.map(({ body, mealIds, usage }): SucceededOutcome => ({
      result: "succeeded",
      body,
      mealIds,
      usage,
    })),
  );
};

type SucceededOutcome = Extract<ReplyAttemptOutcome, { result: "succeeded" }>;

type FailedOutcome = Exclude<ReplyAttemptOutcome, { result: "succeeded" }>;

const toFailedOutcome = (
  error: R.InferFailure<ConversationProvider["generateReply"]>,
): FailedOutcome =>
  match(error)
    .with({ name: "ConversationProviderError" }, ({ errorType, cause }): FailedOutcome => ({
      result: "provider_error",
      usage: undefined,
      errorType,
      // つないでいない提供元のように、応答のエラーが無ければ失敗そのものを送る
      providerError: cause ?? error,
    }))
    .with(
      { name: "ConversationProviderBadRequestError" },
      ({ errorType, cause }): FailedOutcome => ({
        result: "bad_request",
        usage: undefined,
        errorType,
        providerError: cause ?? error,
      }),
    )
    .with({ name: "ConversationProviderTimedOutError" }, (): FailedOutcome => ({
      result: "timed_out",
      usage: undefined,
    }))
    .with({ name: "ConversationProviderInvalidResponseError" }, ({ usage }): FailedOutcome => ({
      result: "invalid_response",
      usage,
    }))
    .exhaustive();

// 指し示せるのは、文脈で ID を付けた食事（listReferableMealIds）のうち、作り終えた時点で在る食事だけ（設計判断 30）。
// 同じ食事を二度指すと並びを持てないので、それも読めない応答にする
const isValidReply = (
  { body, mealIds }: GeneratedReply,
  context: ReplyContext,
  stores: Pick<RecordKindStores, "meal">,
): boolean => {
  const referable = listReferableMealIds(context);
  return (
    body.trim().length > 0 &&
    new Set(mealIds).size === mealIds.length &&
    mealIds.every((mealId) => referable.has(mealId) && stores.meal.find(mealId) !== undefined)
  );
};
