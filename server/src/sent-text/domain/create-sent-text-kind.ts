import { match } from "ts-pattern";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import type { SentText } from "./sent-text";
import type { SentTextStore } from "./sent-text-store";
import { type SentTextWrite, sentTextWriteTypes } from "./sent-text-write";

// 送った文章の種類。消す操作は無いので、消えない種類
export const createSentTextKind = (
  store: SentTextStore,
): RecordKind<"sent_text", SentTextWrite, SentText, AddedRecordType> => ({
  name: "sent_text",
  writes: {
    isWrite: (write): write is SentTextWrite => sentTextWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_sent_text" }, ({ sentText }) => decideCreate(store, sentText))
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "never",
  readCurrent: (recordId): CurrentRecord<SentText> => {
    const sentText = store.find(recordId);
    return sentText === undefined ? { status: "absent" } : { status: "value", value: sentText };
  },
});

// 送った文章の書き込みが、送った文章のほかに変える記録の種類
type AddedRecordType = "sent_text_status";

const decideCreate = (store: SentTextStore, sentText: SentText): WriteDecision<AddedRecordType> => {
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
  if (store.find(sentText.id) !== undefined) {
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
      store.insert(sentText);
    },
  };
};
