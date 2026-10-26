// 出し方のページの例の数字の書き方。kg は向きを文で書くので、符号を落とす
export const formatExampleValue = {
  kcal: (kcal: number) => Math.round(kcal).toLocaleString("en-US"),
  kg: (kg: number, digits: 1 | 2) => Math.abs(kg).toFixed(digits),
  signedKg: (kg: number) => `${kg < 0 ? "−" : "+"}${Math.abs(kg).toFixed(2)}`,
  // 2026-01-12 → 1月12日
  monthDay: (calendarDay: string) => {
    const [, month, day] = calendarDay.split("-").map(Number);
    return `${month}月${day}日`;
  },
  // 2026-01-12 → 1/12
  shortMonthDay: (calendarDay: string) => {
    const [, month, day] = calendarDay.split("-").map(Number);
    return `${month}/${day}`;
  },
  // 2026-01-18 → 18
  dayOfMonth: (calendarDay: string) => Number(calendarDay.split("-")[2]),
};
