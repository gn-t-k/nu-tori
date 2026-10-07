import { match } from "ts-pattern";
import { type DishEstimationSchedule, findNewestActiveSchedule } from "./dish-estimation-schedule";
import type { DishEstimationStatus } from "./dish-estimation-status";

// 取り消していない予定のうちいちばん新しい予定と、その予定の推定・完了・断念だけを見る。前の予定の見送りは見ない
// （見送った予定は取り消されずに残るので、見ると、一度見送られた料理の名前をあとで直したときにも翌日に推定になる）。
// 予定が無い料理は値を持たない（undefined）。now は、まだ始めていない予定が次の日の予定かを決める
export const computeDishEstimationStatus = (
  schedules: readonly DishEstimationSchedule[],
  now: Date,
): DishEstimationStatus | undefined => {
  const newest = findNewestActiveSchedule(schedules);
  if (newest === undefined) {
    return undefined;
  }
  return (
    match(newest.progress)
      .returnType<DishEstimationStatus>()
      // 名前を直して作る予定の due_at は書き込みを受け取った時刻なので、今より先なら見送りから作った次の日の予定
      .with("waiting", () =>
        newest.dueAt.getTime() > now.getTime() ? "deferred_to_next_day" : "estimating",
      )
      .with("deferred", () => "deferred_to_next_day")
      .with("estimating", () => "estimating")
      .with("estimated", () => "estimated")
      .with("no_dishes", () => "no_dishes")
      .with("abandoned", () => "failed")
      .exhaustive()
  );
};
