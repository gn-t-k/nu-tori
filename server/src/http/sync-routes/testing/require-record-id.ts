import type { PullResult } from "./pull-sync-changes";

// 取りに行った変更のうち、条件に合う最初の変更の記録の ID。無ければ、前提の記録ができていないので投げる
export const requireRecordId = (
  changes: PullResult["changes"],
  matches: (change: Change) => boolean,
): string => {
  const found = changes.find(matches);
  if (found === undefined) {
    throw new Error("条件に合う変更が無い");
  }
  return found.recordId;
};

type Change = PullResult["changes"][number];
