export const computeCalendarDay = (instant: Date, timeZone: string): string => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    calendar: "gregory",
    numberingSystem: "latn",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const valueOfPart = (type: "year" | "month" | "day"): string => {
    const value = parts.find((part) => part.type === type)?.value;
    if (value === undefined) {
      throw new Error(`日付の ${type} を取り出せなかった`);
    }
    return value;
  };
  return `${valueOfPart("year")}-${valueOfPart("month")}-${valueOfPart("day")}`;
};
