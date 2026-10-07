import acceptedRanges from "../../../../shared/accepted-ranges.json";

export type AcceptedRange = keyof typeof acceptedRanges;

export const isWithinAcceptedRange = (range: AcceptedRange, value: number): boolean => {
  const { minimum, exclusiveMinimum, maximum }: Bounds = acceptedRanges[range];
  return (
    (minimum === undefined || minimum <= value) &&
    (exclusiveMinimum === undefined || exclusiveMinimum < value) &&
    (maximum === undefined || value <= maximum)
  );
};

// 範囲ごとに、下限（minimum は含む、exclusiveMinimum は含まない）と上限（maximum は含む）の書いてあるものだけを当てる。
// 下限は片方だけにする。両方を書くと、端末の書き出し（AcceptedBounds）は下限を1つしか持てず、判定が食い違う
type Bounds = { maximum?: number } & (
  | { minimum?: number; exclusiveMinimum?: never }
  | { minimum?: never; exclusiveMinimum?: number }
);
