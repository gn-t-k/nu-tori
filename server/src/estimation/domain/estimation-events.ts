import type { RecordId } from "../../domain/record-id";
import type { DistributivePick } from "../../domain/distributive-pick";
import type { EstimationAttemptOutcome } from "./estimation-attempt-outcome";

// 推定の出来事ごとの書く値。書く置き場（EstimationEventWriteStore）と推定の書き込み（EstimationWrites）で形をそろえる
export type EstimationEvents = {
  schedule: { id: string; mealId: RecordId; dueAt: Date; countedOn: string };
  // 料理が対象の予定（名前を直した・料理を足したときの推定し直し）
  dishSchedule: { id: string; dishId: RecordId; dueAt: Date; countedOn: string };
  deferral: { scheduleId: string; deferredAt: Date };
  hold: { scheduleId: string; heldAt: Date };
  estimation: { id: string; scheduleId: string; startedAt: Date };
  attempt: { id: string; estimationId: string; attemptedAt: Date };
  // conclusion は、試みの結果のうち書いて残す分（結果と、提供元のエラーと 400 のときのエラーの種類）
  attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: DistributivePick<EstimationAttemptOutcome, "result" | "errorType">;
  };
  completion: { estimationId: string; completedAt: Date; result: "estimated" | "no_dishes" };
  abandonment: { estimationId: string; abandonedAt: Date };
  // 文章の食事の推定が決めた、予定のつなぎの食事（1つ目の食事）の時刻。食事は推定から辿る
  mealEatenAtEstimation: { estimationId: string; eatenAt: Date };
  // 文章の食事の推定が作った、2つめ以降の食事
  createdMeal: { mealId: RecordId; estimationId: string };
};
