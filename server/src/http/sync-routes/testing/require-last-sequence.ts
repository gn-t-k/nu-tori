import type { PullResult } from "./pull-sync-changes";

// 取りに行った変更の、最後の通し番号。変更が1つも無ければ、前提の記録ができていないので投げる
export const requireLastSequence = (changes: PullResult["changes"]): number => {
  const last = changes.at(-1);
  if (last === undefined) {
    throw new Error("取りに行った変更が無い");
  }
  return last.sequence;
};
