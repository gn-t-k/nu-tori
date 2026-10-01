import { readRows } from "../../../http/sync-routes/testing/read-rows";

// 回数に数えた推定を足す前の、いちばん早い予定の数える日
export const readEarliestCountedOn = async (accountId: string): Promise<string> => {
  const [row] = await readRows(
    accountId,
    "SELECT counted_on FROM estimation_schedules ORDER BY due_at, counted_on LIMIT 1",
  );
  const countedOn = row?.["counted_on"];
  if (typeof countedOn !== "string") {
    throw new Error("予定が無い");
  }
  return countedOn;
};
