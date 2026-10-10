import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { LatestTimeZoneStore } from "../../domain/latest-time-zone-store";
import type { SentText } from "../../sent-text/domain/sent-text";

// 返事の依頼の数える日。依頼を作った時刻の、ユーザーの最新のタイムゾーン（読めなければ文章を送ったときのもの）での日
export const computeReplyRequestCountedOn = (
  requestedAt: Date,
  sentText: Pick<SentText, "timeZone">,
  latestTimeZone: LatestTimeZoneStore,
): string =>
  computeCalendarDayInTimeZone(
    requestedAt,
    findLatestValidTimeZone(latestTimeZone) ?? sentText.timeZone,
  );
