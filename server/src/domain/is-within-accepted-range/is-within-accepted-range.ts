import acceptedRanges from "../../../../shared/accepted-ranges.json";

export type AcceptedRange = keyof typeof acceptedRanges;

export const isWithinAcceptedRange = (range: AcceptedRange, value: number): boolean => {
  const { minimum, maximum } = acceptedRanges[range];
  return minimum <= value && value <= maximum;
};
