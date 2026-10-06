import { desc } from "drizzle-orm";
import { estimationEndedAt } from "../../estimation/durable-object/estimation-ended-at";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";

const { estimations } = estimationTables;

// 当てた推定の新しさは、推定の終わり（完了か断念）の時刻で並べ、同じなら始めた時刻で並べる。
// 推定は終わったときにだけ当てるので、どちらかの時刻を必ず持つ
export const newestDishEstimationFirst = [desc(estimationEndedAt), desc(estimations.startedAt)];
