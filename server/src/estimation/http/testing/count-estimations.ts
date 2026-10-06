import { readRows } from "../../../http/sync-routes/testing/read-rows";

// 推定の予定と推定の行の数。記録を消しても予定と推定が残ることを、消す前と比べて確かめるのに使う
export const countEstimations = async (
  accountId: string,
): Promise<{ estimationSchedules: number; estimations: number }> => {
  const [row] = await readRows(
    accountId,
    `SELECT (SELECT count(*) FROM estimation_schedules) AS estimation_schedules,
            (SELECT count(*) FROM estimations) AS estimations`,
  );
  const estimationSchedules = row?.["estimation_schedules"];
  const estimations = row?.["estimations"];
  if (typeof estimationSchedules !== "number" || typeof estimations !== "number") {
    throw new Error("推定の予定と推定の数を読めない");
  }
  return { estimationSchedules, estimations };
};
