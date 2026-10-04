import { match } from "ts-pattern";
import { isCalendarDay } from "../../domain/is-calendar-day";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { WriteKind } from "../../domain/sync-ledger/write-kind";
import type { SyncWriteOutcome } from "../../domain/sync-write-outcome";
import { isNoticeType, type Notice, type NoticeResponse } from "./notice";
import type { NoticeStore } from "./notice-store";
import { type NoticeWrite, noticeWriteTypes } from "./notice-write";

// 知らせの種類。端末が作り、答える。直す・消す書き込みと削除の印は無い
export const createNoticeKind = (
  store: NoticeStore,
): RecordKind<"notice", NoticeWrite, Notice> => ({
  name: "notice",
  writes: {
    isWrite: (write): write is NoticeWrite => noticeWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_notice" }, ({ notice }) => decideCreate(store, notice))
        .with({ type: "respond_notice" }, ({ noticeId, response }) =>
          decideRespond(store, noticeId, response),
        )
        .exhaustive(),
  },
  follows: undefined,
  deliversAbsence: false,
  readCurrent: (recordId): CurrentRecord<Notice> => {
    const notice = store.find(recordId);
    return notice === undefined ? { status: "absent" } : { status: "value", value: notice };
  },
});

const decideCreate = (
  store: NoticeStore,
  notice: Extract<NoticeWrite, { type: "create_notice" }>["notice"],
): WriteDecision => {
  const { noticeType } = notice;
  if (!isNoticeType(noticeType)) {
    return settled("create", notice.id, { result: "rejected", reason: "invalid_notice_type" });
  }
  if (!isTimeZoneName(notice.timeZone)) {
    return settled("create", notice.id, { result: "rejected", reason: "invalid_time_zone" });
  }
  if (!isCalendarDay(notice.targetOn)) {
    return settled("create", notice.id, { result: "rejected", reason: "invalid_target_on" });
  }
  // 2台目の作る書き込みで、1台目で答えた知らせを答えていない形に戻さない
  if (store.find(notice.id) !== undefined) {
    return settled("create", notice.id, { result: "ignored_duplicate" });
  }
  return applied("create", notice.id, () => {
    store.insert({ ...notice, noticeType });
  });
};

const decideRespond = (
  store: NoticeStore,
  noticeId: string,
  response: NoticeResponse,
): WriteDecision => {
  if (!isTimeZoneName(response.timeZone)) {
    return settled("respond", noticeId, { result: "rejected", reason: "invalid_time_zone" });
  }
  const notice = store.find(noticeId);
  if (notice === undefined) {
    return settled("respond", noticeId, { result: "rejected", reason: "record_not_found" });
  }
  // 2台の両方で答えたとき、先に受け取ったほうを残す
  if (notice.response !== undefined) {
    return settled("respond", noticeId, { result: "ignored_duplicate" });
  }
  return applied("respond", noticeId, (receiptId) => {
    store.insertResponse(receiptId, noticeId, response);
  });
};

// 行を書かずに終わる
const settled = (
  writeKind: WriteKind,
  recordId: string,
  outcome: Exclude<SyncWriteOutcome, { result: "applied" }>,
): WriteDecision => ({
  writeKind,
  recordId,
  outcome,
  changedRecordId: undefined,
  addedChanges: [],
  usageEvents: [],
  commit: () => undefined,
});

const applied = (
  writeKind: WriteKind,
  recordId: string,
  commit: WriteDecision["commit"],
): WriteDecision => ({
  writeKind,
  recordId,
  outcome: { result: "applied" },
  changedRecordId: recordId,
  addedChanges: [],
  usageEvents: [],
  commit,
});
