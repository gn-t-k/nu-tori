// 栄養の量として読める数（有限で 0 以上）か
export const isNonNegative = (value: number): boolean => Number.isFinite(value) && value >= 0;
