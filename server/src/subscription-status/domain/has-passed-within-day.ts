import { millisecondsPerDay } from "../../domain/milliseconds-per-day";

// 区切りの時刻 time を、今から前の 24 時間の内に過ぎたか。
// 課金の仕事のアラームはその時刻に動くので、ほかの仕事で動いたアラームと見分けるのに使う
// （24 時間の内に別のアラームが動くと2度目になるのを受け入れる）
export const hasPassedWithinDay = (time: Date | undefined, now: Date): boolean =>
  time !== undefined &&
  time.getTime() <= now.getTime() &&
  now.getTime() - time.getTime() < millisecondsPerDay;
