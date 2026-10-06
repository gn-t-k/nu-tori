import acceptedRanges from "../../../../shared/accepted-ranges.json";

export type AcceptedRange = keyof typeof acceptedRanges;

// 範囲ごとに、下限（minimum は含む、exclusiveMinimum は含まない）と上限（maximum は含む）の書いてあるものだけを当てる
type Bounds = { minimum?: number; exclusiveMinimum?: number; maximum?: number };

export const isWithinAcceptedRange = (range: AcceptedRange, value: number): boolean => {
  const { minimum, exclusiveMinimum, maximum }: Bounds = acceptedRanges[range];
  return (
    (minimum === undefined || minimum <= value) &&
    (exclusiveMinimum === undefined || exclusiveMinimum < value) &&
    (maximum === undefined || value <= maximum)
  );
};
