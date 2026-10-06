// 料理が対象の推定の予定ごとの、予定から先の出来事。見送った予定は推定を始めない。始めた予定は、完了か断念が来るまで推定中
// 推定を始めた予定だけが、始めた推定の ID を持つ
export type DishEstimationSchedule = {
  scheduleId: string;
  dueAt: Date;
  // 名前をまた直して取り消した予定
  cancelled: boolean;
} & (
  | { progress: "waiting" | "deferred" }
  | { progress: "estimating" | "estimated" | "no_dishes" | "abandoned"; estimationId: string }
);

// 取り消していない予定のうち、due_at がいちばん新しいもの。料理ごとの推定の状態と、届いた推定を当てるかは、この予定で決める。
// 見送りから作る次の日の予定は、見送りと同じトランザクションで足し、due_at が見送った予定より後なので、見送った予定がこれになることは無い
export const findNewestActiveSchedule = (
  schedules: readonly DishEstimationSchedule[],
): DishEstimationSchedule | undefined =>
  schedules
    .filter(({ cancelled }) => !cancelled)
    .toSorted((a, b) => b.dueAt.getTime() - a.dueAt.getTime())[0];

// まだ始まっていない予定（推定も見送りも無く、取り消していない予定）。名前をまた直したときに取り消す
export const findWaitingSchedules = (
  schedules: readonly DishEstimationSchedule[],
): DishEstimationSchedule[] =>
  schedules.filter(({ cancelled, progress }) => !cancelled && progress === "waiting");

// 料理の推定を始めて、まだ完了も断念もしていない推定。名前をまた直したときに前の推定が呼び出し中なら、2つ以上並ぶ
export const findOngoingEstimationIds = (schedules: readonly DishEstimationSchedule[]): string[] =>
  schedules.flatMap((schedule) =>
    schedule.progress === "estimating" ? [schedule.estimationId] : [],
  );

// 推定し直しの書き込みを受け取った時刻。その推定の予定から、見送りでつながった前の予定を辿った、いちばん早い予定の時刻
export const findReceivedAtOfEstimation = (
  schedules: readonly DishEstimationSchedule[],
  estimationId: string,
): Date => {
  const own = schedules.find(
    (schedule) => "estimationId" in schedule && schedule.estimationId === estimationId,
  );
  if (own === undefined) {
    throw new Error(`推定を始めた料理の予定が無い: ${estimationId}`);
  }
  return findReceivedAtOfSchedule(schedules, own.scheduleId);
};

// 予定のもとの書き込みを受け取った時刻。その予定から、見送りでつながった前の予定を辿った、いちばん早い予定の時刻。
// 見送りから作る次の日の予定は見送った予定とつながず別の予定なので、due_at の並びで、すぐ前が取り消していない見送った予定である間だけ遡る
export const findReceivedAtOfSchedule = (
  schedules: readonly DishEstimationSchedule[],
  scheduleId: string,
): Date => {
  const sorted = schedules.toSorted((a, b) => b.dueAt.getTime() - a.dueAt.getTime());
  const ownIndex = sorted.findIndex((schedule) => schedule.scheduleId === scheduleId);
  const own = sorted[ownIndex];
  if (own === undefined) {
    throw new Error(`料理の予定が無い: ${scheduleId}`);
  }
  let receivedAt = own.dueAt;
  for (const previous of sorted.slice(ownIndex + 1)) {
    if (previous.cancelled || previous.progress !== "deferred") {
      break;
    }
    receivedAt = previous.dueAt;
  }
  return receivedAt;
};
