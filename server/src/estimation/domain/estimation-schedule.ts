// 推定の予定ごとの、予定から先の出来事（食事が対象の予定も、料理が対象の予定も同じ形）。見送った・保留した予定は推定を始めない。
// 始めた予定は、完了か断念が来るまで推定中。推定を始めた予定だけが、始めた推定の ID を持つ。
// 取り消した予定は、前に書いた取り消しの行から読むだけで、推定も見送りも持たない（取り消しを書くのは、#381 より前の料理の予定だけ）
export type EstimationSchedule = { scheduleId: string; dueAt: Date } & (
  | { progress: "cancelled" }
  | { progress: "waiting" | "deferred" | "held" }
  | { progress: "estimating" | "estimated" | "no_dishes" | "abandoned"; estimationId: string }
);
