// テストの今（偽の時計）の、東京での日付。端末のタイムゾーンを東京にしたアカウントの数える日
export const todayInTokyo = (): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
