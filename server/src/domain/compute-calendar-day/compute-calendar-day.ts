export const computeCalendarDay = (instant: Date, utcOffsetSeconds: number): string => {
  const localInstant = new Date(instant.getTime() + utcOffsetSeconds * 1000);
  return localInstant.toISOString().slice(0, "YYYY-MM-DD".length);
};
