// 食べた量のある日から、食べた量が中央値の半分に満たない日（1食だけ記録した日など）を外す。
// 日が少ないと中央値そのものが部分的な記録に引かれるので、7日未満なら外さない
export const excludePartiallyRecordedDays = <TDay extends { kcal: number }>(
  days: readonly TDay[],
): TDay[] => {
  const minimumDaysToExclude = 7;
  if (days.length < minimumDaysToExclude) {
    return [...days];
  }
  const threshold = computeMedian(days.map(({ kcal }) => kcal)) / 2;
  return days.filter(({ kcal }) => threshold <= kcal);
};

// 空の並びを渡さない
const computeMedian = (values: readonly number[]): number => {
  const sorted = values.toSorted((a, b) => a - b);
  const upper = sorted[Math.floor(sorted.length / 2)];
  const lower = sorted[Math.ceil(sorted.length / 2) - 1];
  if (upper === undefined || lower === undefined) {
    throw new Error("中央値を出す値が無い");
  }
  return (lower + upper) / 2;
};
