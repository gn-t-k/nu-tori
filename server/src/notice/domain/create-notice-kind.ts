import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { isCalendarDay } from "../../domain/is-calendar-day";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
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
  whenGone: "never",
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
    return rejectWrite("create", notice.id, "invalid_notice_type");
  }
  if (!isTimeZoneName(notice.timeZone)) {
    return rejectWrite("create", notice.id, "invalid_time_zone");
  }
  if (!isCalendarDay(notice.targetOn)) {
    return rejectWrite("create", notice.id, "invalid_target_on");
  }
  // 2台目の作る書き込みで、1台目で答えた知らせを答えていない形に戻さない
  if (store.find(notice.id) !== undefined) {
    return { result: "ignored_duplicate", writeKind: "create", recordId: notice.id };
  }
  return {
    result: "applied",
    writeKind: "create",
    recordId: notice.id,
    addedChanges: [],
    usageEvents: [],
    commit: () => {
      store.insert({ ...notice, noticeType });
    },
  };
};

const decideRespond = (
  store: NoticeStore,
  noticeId: RecordId,
  response: NoticeResponse,
): WriteDecision => {
  if (!isTimeZoneName(response.timeZone)) {
    return rejectWrite("respond", noticeId, "invalid_time_zone");
  }
  const notice = store.find(noticeId);
  if (notice === undefined) {
    return rejectWrite("respond", noticeId, "record_not_found");
  }
  // 2台の両方で答えたとき、先に受け取ったほうを残す
  if (notice.response !== undefined) {
    return { result: "ignored_duplicate", writeKind: "respond", recordId: noticeId };
  }
  return {
    result: "applied",
    writeKind: "respond",
    recordId: noticeId,
    addedChanges: [],
    usageEvents: [],
    commit: (receiptId) => {
      store.insertResponse(receiptId, noticeId, response);
    },
  };
};
