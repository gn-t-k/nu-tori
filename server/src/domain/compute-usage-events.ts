import { computeCalendarDay } from "./compute-calendar-day";
import { isTimeZoneName } from "./is-time-zone-name";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { UsageEvent } from "./usage-event";

// 要求の書き込みを当て終えたあとの設定で決める。利用状況を送らない人には、この要求で切り替えた場合も含めて何も返さない
export const computeUsageEvents = (
  store: SyncStore,
  request: {
    clientState: SyncClientState;
    receivedAt: Date;
    previousRequestReceivedAt: Date | undefined;
    rejectedWrites: Extract<UsageEvent, { name: "sync_write_rejected" }>[];
  },
): UsageEvent[] => {
  if (!(store.findAccountSettings()?.sendsUsageData ?? true)) {
    return [];
  }
  const pendingWritesReported = computePendingWritesReported(request);
  return pendingWritesReported === undefined
    ? request.rejectedWrites
    : [...request.rejectedWrites, pendingWritesReported];
};

const computePendingWritesReported = ({
  clientState,
  receivedAt,
  previousRequestReceivedAt,
}: {
  clientState: SyncClientState;
  receivedAt: Date;
  previousRequestReceivedAt: Date | undefined;
}): UsageEvent | undefined => {
  const stuckAfterSeconds = 3600;
  const oldestPendingWriteAgeSeconds = clientState.oldestPendingWriteAgeSeconds;
  if (
    oldestPendingWriteAgeSeconds === undefined ||
    oldestPendingWriteAgeSeconds <= stuckAfterSeconds
  ) {
    return undefined;
  }
  // 届いたまま控えたタイムゾーンは、日付の計算に使う前にここで確かめる
  if (!isTimeZoneName(clientState.timeZone)) {
    return undefined;
  }
  const isFirstRequestOfDay =
    previousRequestReceivedAt === undefined ||
    computeCalendarDay(previousRequestReceivedAt, clientState.timeZone) !==
      computeCalendarDay(receivedAt, clientState.timeZone);
  return isFirstRequestOfDay
    ? {
        name: "sync_pending_writes_reported",
        pendingWriteCount: clientState.pendingWriteCount,
        oldestPendingWriteAgeSeconds,
      }
    : undefined;
};
