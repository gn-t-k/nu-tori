import { computeCalendarDayInTimeZone } from "./compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "./is-time-zone-name";
import type { SyncClientState } from "./sync-client-state";
import type { UsageEvent } from "./usage-event";

// 要求の書き込みを当て終えたあとの設定で決める。利用状況を送らない人には、この要求で切り替えた場合も含めて何も返さない
export const computeUsageEvents = (request: {
  clientState: SyncClientState;
  sendsUsageData: boolean;
  receivedAt: Date;
  previousRequestReceivedAt: Date | undefined;
  rejectedWrites: Extract<UsageEvent, { name: "sync_write_rejected" }>[];
}): UsageEvent[] => {
  if (!request.sendsUsageData) {
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
    computeCalendarDayInTimeZone(previousRequestReceivedAt, clientState.timeZone) !==
      computeCalendarDayInTimeZone(receivedAt, clientState.timeZone);
  return isFirstRequestOfDay
    ? {
        name: "sync_pending_writes_reported",
        pendingWriteCount: clientState.pendingWriteCount,
        oldestPendingWriteAgeSeconds,
      }
    : undefined;
};
