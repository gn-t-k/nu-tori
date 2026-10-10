// 時差を当てた日時（YYYY-MM-DDTHH:mm）
export const formatLocalDateTime = (instant: Date, utcOffsetSeconds: number): string =>
  new Date(instant.getTime() + utcOffsetSeconds * 1000)
    .toISOString()
    .slice(0, "YYYY-MM-DDTHH:mm".length);
