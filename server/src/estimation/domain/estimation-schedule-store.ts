import type { EstimationTarget } from "./estimation-target";

// 推定の予定と、食事・料理とのつなぎを読む置き場。書くのは推定の書き込みの口（writeEstimationEvents）だけ
export type EstimationScheduleStore = {
  hasScheduleOfMeal: (mealId: string) => boolean;
  // 待っている予定（推定も見送りも取り消しも無く、食事か料理につながっている）のうち、いちばん早い時刻
  findEarliestWaitingDueAt: () => Date | undefined;
  // 待っている予定のうち、時刻が来たもの（早い順）
  findDueWaitingSchedules: (
    now: Date,
  ) => { scheduleId: string; target: EstimationTarget; countedOn: string }[];
  // 食事を受け取った（写真がそろって予定に入れた）時刻。見送りで足した予定より前の、いちばん早い予定の時刻
  findEarliestDueAtOfMeal: (mealId: string) => Date | undefined;
};
