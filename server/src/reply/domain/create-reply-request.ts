import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { LatestTimeZoneStore } from "../../domain/latest-time-zone-store";
import { generateRecordId } from "../../domain/record-id";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { ReplyRequest } from "./reply-request";

// 送った文章への返事の依頼を作る。
// 数える日は、依頼を作った時刻の、ユーザーの最新のタイムゾーン（読めなければ文章を送ったときのもの）での日
export const createReplyRequest = (
  sentText: Pick<SentText, "id" | "timeZone">,
  requestedAt: Date,
  latestTimeZone: LatestTimeZoneStore,
  trigger: ReplyRequest["trigger"],
): ReplyRequest => ({
  id: generateRecordId(),
  sentTextId: sentText.id,
  countedOn: computeCalendarDayInTimeZone(
    requestedAt,
    findLatestValidTimeZone(latestTimeZone) ?? sentText.timeZone,
  ),
  trigger,
});
