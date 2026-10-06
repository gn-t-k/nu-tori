import { sql } from "drizzle-orm";
import { estimationTables } from "./estimation-tables";

const { estimationCompletions, estimationAbandonments } = estimationTables;

// 推定の終わり（完了か断念）の時刻。完了と断念の表を推定に左結合した問い合わせで使う
export const estimationEndedAt = sql<number>`coalesce(${estimationCompletions.completedAt}, ${estimationAbandonments.abandonedAt})`;
