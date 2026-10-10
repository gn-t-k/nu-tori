import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeSentTextReplyStatus } from "../../sent-text-status/domain/compute-sent-text-reply-status";
import type { ReplyStreamEnding } from "./reply-stream-event";

// 見守る要求から見た、送った文章の今。返事の生成を始めていれば、待っているあいだも返事の ID が分かる
export type ReplyWatchState =
  | { type: "absent" }
  | { type: "waiting"; replyId: RecordId | undefined }
  | { type: "ended"; ending: ReplyStreamEnding };

// 送った文章の状態と同じ出し方で、読み分けと応答の状態から決める
export const readReplyWatchState = (
  stores: Pick<RecordKindStores, "sentText" | "sentTextStatus" | "reply" | "aiUtterance">,
  sentTextId: RecordId,
): ReplyWatchState => {
  if (stores.sentText.find(sentTextId) === undefined) {
    return { type: "absent" };
  }
  return (
    match(computeSentTextReplyStatus(stores.sentTextStatus.findReplyRequestProgresses(sentTextId)))
      .returnType<ReplyWatchState>()
      .with({ type: "awaiting" }, () => ({
        type: "waiting",
        replyId: stores.reply.findContinuingGenerationId(sentTextId),
      }))
      .with({ type: "replied" }, () => {
        const utterance = stores.aiUtterance.findOfSentText(sentTextId);
        if (utterance === undefined) {
          throw new Error("返事ありの文章に、返事が無い");
        }
        return { type: "ended", ending: { type: "replied", replyId: utterance.id } };
      })
      .with({ type: "halted" }, () => ({ type: "ended", ending: { type: "reply_halted" } }))
      .with({ type: "failed" }, ({ reason }) => ({
        type: "ended",
        ending: { type: "reply_failed", failureReason: reason },
      }))
      // 依頼が無いのは、読み分けを待っているか、食事と読み分けたとき
      .with({ type: "none" }, () =>
        stores.sentTextStatus.findClassification(sentTextId) === "meal"
          ? { type: "ended", ending: { type: "classified_as_meal" } }
          : { type: "waiting", replyId: undefined },
      )
      .exhaustive()
  );
};
