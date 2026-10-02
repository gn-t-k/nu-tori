// YYYY-MM-DD の形で、暦にある日付か（2月30日などは読めない）
export const isCalendarDay = (value: string): boolean => {
  if (!/^\d{4}-\d{2}-\d{2}$/u.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(value);
};
