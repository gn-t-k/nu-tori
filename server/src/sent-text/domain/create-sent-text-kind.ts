import { match } from "ts-pattern";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import {
  type MealDeletionChangeType,
  type MealDeletionStores,
  planMealDeletion,
} from "../../meal/domain/plan-meal-deletion";
import { computeReplyRequestCountedOn } from "../../reply/domain/compute-reply-request-counted-on";
import type { ReplyRequest } from "../../reply/domain/reply-request";
import { computeSentTextReplyStatus } from "../../sent-text-status/domain/compute-sent-text-reply-status";
import type { SentText } from "./sent-text";
import { type SentTextWrite, sentTextWriteTypes } from "./sent-text-write";

// 送った文章の種類。消す操作は無いので、消えない種類。receivedAt は要求を受け取った時刻
export const createSentTextKind = (
  stores: SentTextKindStores,
  receivedAt: Date,
): RecordKind<"sent_text", SentTextWrite, SentText, AddedRecordType> => ({
  name: "sent_text",
  writes: {
    isWrite: (write): write is SentTextWrite => sentTextWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_sent_text" }, ({ sentText }) => decideCreate(stores, sentText))
        .with({ type: "resend_sent_text_as_conversation" }, ({ sentTextId }) =>
          decideResendAsConversation(stores, sentTextId, receivedAt),
        )
        .with({ type: "resend_sent_text" }, ({ sentTextId }) =>
          decideResend(stores, sentTextId, receivedAt),
        )
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "never",
  readCurrent: (recordId): CurrentRecord<SentText> => {
    const sentText = stores.sentText.find(recordId);
    return sentText === undefined ? { status: "absent" } : { status: "value", value: sentText };
  },
});

// 送った文章の書き込みが、送った文章のほかに変える記録の種類。会話として送り直すと、文章の食事が消える
type AddedRecordType = "sent_text_status" | "meal" | MealDeletionChangeType;

// 送った文章の書き込みが読み書きする置き場
type SentTextKindStores = MealDeletionStores &
  Pick<RecordKindStores, "sentText" | "sentTextStatus" | "writeReplyEvents" | "latestTimeZone">;

const decideCreate = (
  stores: SentTextKindStores,
  sentText: SentText,
): WriteDecision<AddedRecordType> => {
  // 端末と同じ数になるよう、UTF-16 の単位でなくコードポイントで数える（docs/agents/shared-rules.md）
  if (
    !isWithinAcceptedRange("sentTextBodyTrimmedLength", Array.from(sentText.body.trim()).length)
  ) {
    return rejectWrite("create", sentText.id, "out_of_range");
  }
  // 知らないタイムゾーンは invalid_time_zone でなく out_of_range にする（#419 の「受け付ける値」）
  if (!isTimeZoneName(sentText.timeZone)) {
    return rejectWrite("create", sentText.id, "out_of_range");
  }
  if (stores.sentText.find(sentText.id) !== undefined) {
    return { result: "ignored_duplicate", writeKind: "create", recordId: sentText.id };
  }
  return {
    result: "applied",
    writeKind: "create",
    recordId: sentText.id,
    // 読み分けを待っている状態を、送った文章と一緒に届ける
    addedChanges: [{ recordType: "sent_text_status", recordId: sentText.id }],
    usageEvents: [],
    commit: () => {
      stores.sentText.insert(sentText);
    },
  };
};

// 食事と読み分けた文章を会話にし、その文章から作った食事（料理と材料を含む）をすべて消して、返事の依頼を作る
// （#419 の「会話として送り直す」）。食事は食事を消す書き込みと同じく消し、削除の印は conversation_resend_meal_deletions に書く。
// 推定の行は消さないので、使った推定の回数は戻らない
const decideResendAsConversation = (
  stores: SentTextKindStores,
  sentTextId: RecordId,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const sentText = stores.sentText.find(sentTextId);
  if (sentText === undefined) {
    return rejectWrite("resend_as_conversation", sentTextId, "record_not_found");
  }
  const classification = stores.sentTextStatus.findClassification(sentTextId);
  if (classification === undefined) {
    return rejectWrite("resend_as_conversation", sentTextId, "not_classified_as_meal");
  }
  // 2台目の端末から押した・2回目の書き込み。望みはもう叶っているので、行も変更も足さない（設計判断 29）
  if (classification === "conversation") {
    return { result: "unchanged", writeKind: "resend_as_conversation", recordId: sentTextId };
  }
  const deletions = stores.sentText
    .findMealIds(sentTextId)
    .map((mealId) => ({ mealId, plan: planMealDeletion(stores, mealId, receivedAt) }));
  return {
    result: "applied",
    writeKind: "resend_as_conversation",
    recordId: sentTextId,
    addedChanges: [
      { recordType: "sent_text_status", recordId: sentTextId },
      ...deletions.flatMap(({ mealId, plan }) => [
        { recordType: "meal" as const, recordId: mealId },
        ...plan.addedChanges,
      ]),
    ],
    usageEvents: deletions.flatMap(({ plan }) => plan.usageEvents),
    // 消した食事の削除の印は、会話として送り直したことの行を指すので、先にその行を書く
    commit: (receiptId, addChange) => {
      stores.sentText.insertConversationResend(receiptId);
      for (const { mealId, plan } of deletions) {
        plan.commit(receiptId, () => {
          stores.sentText.insertConversationResendMealDeletion(receiptId, mealId);
        });
      }
      writeReplyRequest(stores, addChange, {
        sentText,
        receivedAt,
        trigger: { type: "conversation_resend", receiptId },
      });
    },
  };
};

// 返事を作れなかった・回数切れの文章に、返事の依頼を作り直す（#419 の「作れなかった・回数切れ」）。
// 回数は新しい依頼の数える日でまた数えるので、回数切れの文章も翌日に送り直せば通る
const decideResend = (
  stores: SentTextKindStores,
  sentTextId: RecordId,
  receivedAt: Date,
): WriteDecision<AddedRecordType> => {
  const sentText = stores.sentText.find(sentTextId);
  if (sentText === undefined) {
    return rejectWrite("resend", sentTextId, "record_not_found");
  }
  const replyStatus = computeSentTextReplyStatus(
    stores.sentTextStatus.findReplyRequestProgresses(sentTextId),
  );
  return (
    match(replyStatus)
      .returnType<WriteDecision<AddedRecordType>>()
      // 返事を頼んでいない文章（読み分ける前、食事と読み分けた文章）
      .with({ type: "none" }, () => rejectWrite("resend", sentTextId, "reply_not_failed"))
      // 2台目の端末から押した・2回目の書き込み。返事は来るか来ているので、行も変更も足さず、回数を2回使わない（設計判断 29）
      .with({ type: "awaiting" }, { type: "replied" }, () => ({
        result: "unchanged",
        writeKind: "resend",
        recordId: sentTextId,
      }))
      .with({ type: "halted" }, { type: "failed" }, () => ({
        result: "applied",
        writeKind: "resend",
        recordId: sentTextId,
        addedChanges: [{ recordType: "sent_text_status", recordId: sentTextId }],
        usageEvents: [],
        // 依頼のきっかけは送り直したことの行を指すので、先にその行を書く
        commit: (receiptId, addChange) => {
          stores.sentText.insertResend(receiptId);
          writeReplyRequest(stores, addChange, {
            sentText,
            receivedAt,
            trigger: { type: "resend", receiptId },
          });
        },
      }))
      .exhaustive()
  );
};

// 送り直しの返事の依頼を書く。数える日は、受け取った時刻の、ユーザーの最新のタイムゾーンでの日（読めなければ文章のタイムゾーン）
const writeReplyRequest = (
  stores: SentTextKindStores,
  addChange: (change: RecordChangeTarget<AddedRecordType>) => void,
  {
    sentText,
    receivedAt,
    trigger,
  }: { sentText: SentText; receivedAt: Date; trigger: ReplyRequest["trigger"] },
): void => {
  // 依頼を書くだけなので、口が足すのは送った文章の状態の変更だけ（返事の変更は足されない）。
  // 状態の変更は addedChanges にもあり、帳簿が1つにまとめる
  stores.writeReplyEvents(
    (change) => {
      if (change.recordType === "sent_text_status") {
        addChange({ recordType: change.recordType, recordId: change.recordId });
      }
    },
    (writes) => {
      writes.request({
        id: generateRecordId(),
        sentTextId: sentText.id,
        countedOn: computeReplyRequestCountedOn(receivedAt, sentText, stores.latestTimeZone),
        trigger,
      });
    },
  );
};
