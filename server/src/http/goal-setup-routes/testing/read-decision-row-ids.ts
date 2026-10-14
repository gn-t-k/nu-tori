import { readRows } from "../../sync-routes/testing/read-rows";

// 目標を決めたときに書く表の行の ID。決めなかった要求が何も書いていないことを確かめる
export const readDecisionRowIds = (accountId: string) =>
  readRows(
    accountId,
    "SELECT id FROM goals UNION ALL SELECT id FROM expenditure_estimates UNION ALL SELECT id FROM daily_guides UNION ALL SELECT id FROM goal_decision_receipts",
  );
