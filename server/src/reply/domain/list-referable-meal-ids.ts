import type { RecordId } from "../../domain/record-id";
import type { ReplyContext } from "./reply-context";

// 返事が指し示せる食事の ID。文脈で ID を付けた食事（今日と昨日の食事、記録の印の食事）だけ（設計判断 30）。
// 試みの確かめと、返事の評価（server/evals/reply）が同じ決まりを使う
export const listReferableMealIds = (context: ReplyContext): ReadonlySet<RecordId> =>
  new Set<RecordId>([
    ...context.structuredValues.todayMeals.map(({ mealId }) => mealId),
    ...context.structuredValues.yesterdayMeals.map(({ mealId }) => mealId),
    ...context.window.flatMap((entry) => (entry.type === "meal_recorded" ? [entry.mealId] : [])),
  ]);
