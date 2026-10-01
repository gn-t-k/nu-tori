// 推定の予定と、食事とのつなぎを読み書きする置き場
export type EstimationScheduleStore = {
  hasScheduleOfMeal: (mealId: string) => boolean;
  // 予定とつなぎを書く
  insertMealSchedule: (schedule: {
    id: string;
    dueAt: Date;
    countedOn: string;
    mealId: string;
  }) => void;
  // 待っている予定（推定も見送りも無く、食事につながっている）のうち、いちばん早い時刻
  findEarliestWaitingDueAt: () => Date | undefined;
  // 最新の同期の要求の控えのタイムゾーン。届いたまま控えたもので、IANA 名とは限らない
  findLatestTimeZone: () => string | undefined;
};
