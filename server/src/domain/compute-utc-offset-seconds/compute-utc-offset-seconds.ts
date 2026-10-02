// timeZone は isTimeZoneName で確かめた IANA 名を渡す
export const computeUtcOffsetSeconds = (instant: Date, timeZone: string): number => {
  const parts = findFormat(timeZone).formatToParts(instant);
  const valueOfPart = (type: "year" | "month" | "day" | "hour" | "minute" | "second"): number => {
    const value = parts.find((part) => part.type === type)?.value;
    if (value === undefined) {
      throw new Error(`時刻の ${type} を取り出せなかった`);
    }
    return Number(value);
  };
  const wallClockAsUtcMilliseconds = Date.UTC(
    valueOfPart("year"),
    valueOfPart("month") - 1,
    valueOfPart("day"),
    valueOfPart("hour"),
    valueOfPart("minute"),
    valueOfPart("second"),
  );
  // 壁時計は秒までしか持たないので、ミリ秒を切り捨てた時刻と比べる
  const instantInWholeSeconds = Math.floor(instant.getTime() / 1000) * 1000;
  return (wallClockAsUtcMilliseconds - instantInWholeSeconds) / 1000;
};

// 書式を作るのは重いので、タイムゾーンごとに1つ作って使い回す（体重記録を書き込みのたびに並べて読むため）
const formats = new Map<string, Intl.DateTimeFormat>();

const findFormat = (timeZone: string): Intl.DateTimeFormat => {
  const cached = formats.get(timeZone);
  if (cached !== undefined) {
    return cached;
  }
  const format = new Intl.DateTimeFormat("en-US", {
    timeZone,
    calendar: "gregory",
    numberingSystem: "latn",
    hourCycle: "h23",
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    second: "numeric",
  });
  formats.set(timeZone, format);
  return format;
};
