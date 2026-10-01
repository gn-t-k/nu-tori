import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";

// 数える日 countedOn（YYYY-MM-DD）の次の日と、timeZone でのその日の 0:00。timeZone は isTimeZoneName で確かめた IANA 名を渡す
export const computeNextDayStart = (
  countedOn: string,
  timeZone: string,
): { countedOn: string; startsAt: Date } => {
  const nextDayUtcMidnight = Date.parse(`${countedOn}T00:00:00Z`) + 86_400_000;
  const nextDay = new Date(nextDayUtcMidnight).toISOString().slice(0, "YYYY-MM-DD".length);
  // 時差は -12 時間から +14 時間なので、UTC の 0:00 の15時間前はまだ前の日、13時間後はもう次の日。秒の単位で二分探索する
  let beforeStartSeconds = (nextDayUtcMidnight - 15 * 3_600_000) / 1000;
  let startSeconds = (nextDayUtcMidnight + 13 * 3_600_000) / 1000;
  while (startSeconds - beforeStartSeconds > 1) {
    const middleSeconds = Math.floor((beforeStartSeconds + startSeconds) / 2);
    if (computeCalendarDayInTimeZone(new Date(middleSeconds * 1000), timeZone) >= nextDay) {
      startSeconds = middleSeconds;
    } else {
      beforeStartSeconds = middleSeconds;
    }
  }
  return { countedOn: nextDay, startsAt: new Date(startSeconds * 1000) };
};
