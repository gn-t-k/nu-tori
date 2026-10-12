// 候補のうち、いちばん早い時刻。どれも無ければ undefined
export const findEarliest = (candidates: readonly (Date | undefined)[]): Date | undefined =>
  candidates
    .filter((candidate) => candidate !== undefined)
    .toSorted((a, b) => a.getTime() - b.getTime())[0];
