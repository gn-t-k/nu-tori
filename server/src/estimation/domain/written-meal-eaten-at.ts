import { computeUtcOffsetSeconds } from "../../domain/compute-utc-offset-seconds";
import { millisecondsPerDay } from "../../domain/milliseconds-per-day";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { DayOfWeek, LocalDateTime, WrittenMealsRequest } from "./estimation-provider";

// 文章の食事の ① に渡すもの。日時と曜日は、推定する時点でなく送った時刻の、送ったときのタイムゾーンでのもの（翌日に推定するときも）
export const toWrittenMealsRequest = (
  sentText: Pick<SentText, "body" | "sentAt" | "timeZone">,
): WrittenMealsRequest => {
  const wallClock = new Date(
    sentText.sentAt.getTime() + computeUtcOffsetSeconds(sentText.sentAt, sentText.timeZone) * 1000,
  );
  return {
    body: sentText.body,
    sentAt: {
      localDateTime: wallClock.toISOString().slice(0, "YYYY-MM-DDTHH:mm".length),
      dayOfWeek: daysOfWeek[wallClock.getUTCDay()] ?? "sunday",
    },
  };
};

// ① が返した日時を、送ったときのタイムゾーンで時刻にする。読めない日時は undefined（読めない応答）。
// 範囲は #28 のとおりで、送った時刻より後か、送った時刻の 7 日より前なら、送った時刻にする（#419 の「時刻の決め方」）
export const computeWrittenMealEatenAt = (
  localDateTime: LocalDateTime,
  sentText: Pick<SentText, "sentAt" | "timeZone">,
): Date | undefined => {
  const wallClockAsUtc = parseLocalDateTime(localDateTime);
  if (wallClockAsUtc === undefined) {
    return undefined;
  }
  // 時差はその時刻で変わる（夏時間）ので、仮の時刻の時差で一度戻し、戻した時刻の時差で決める
  const guess = new Date(
    wallClockAsUtc - computeUtcOffsetSeconds(new Date(wallClockAsUtc), sentText.timeZone) * 1000,
  );
  const eatenAt = new Date(
    wallClockAsUtc - computeUtcOffsetSeconds(guess, sentText.timeZone) * 1000,
  );
  const earliest = sentText.sentAt.getTime() - 7 * millisecondsPerDay;
  return eatenAt.getTime() > sentText.sentAt.getTime() || eatenAt.getTime() < earliest
    ? sentText.sentAt
    : eatenAt;
};

const daysOfWeek: readonly DayOfWeek[] = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

// 日付として無い日（2月30日など）は、Date が繰り上げるので、書き戻して同じかで見分ける
const parseLocalDateTime = (localDateTime: string): number | undefined => {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/u.test(localDateTime)) {
    return undefined;
  }
  const parsed = Date.parse(`${localDateTime}:00Z`);
  return Number.isNaN(parsed) || new Date(parsed).toISOString().slice(0, 16) !== localDateTime
    ? undefined
    : parsed;
};
