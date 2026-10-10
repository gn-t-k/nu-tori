import { computeDayOfWeek } from "../../domain/compute-day-of-week";
import { computeUtcOffsetSeconds } from "../../domain/compute-utc-offset-seconds";
import { formatLocalDateTime } from "../../domain/format-local-date-time";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { WrittenMealsRequest } from "./estimation-provider";

// 文章の食事の ① に渡すもの。日時と曜日は、推定する時点でなく送った時刻の、送ったときのタイムゾーンでのもの（翌日に推定するときも）
export const toWrittenMealsRequest = (
  sentText: Pick<SentText, "body" | "sentAt" | "timeZone">,
): WrittenMealsRequest => {
  const localDateTime = formatLocalDateTime(
    sentText.sentAt,
    computeUtcOffsetSeconds(sentText.sentAt, sentText.timeZone),
  );
  return {
    body: sentText.body,
    sentAt: {
      localDateTime,
      dayOfWeek: computeDayOfWeek(localDateTime.slice(0, "YYYY-MM-DD".length)),
    },
  };
};
