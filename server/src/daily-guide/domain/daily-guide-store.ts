import type { RecordId } from "../../domain/record-id";
import type { DailyGuide } from "./daily-guide";

export type DailyGuideStore = {
  find: (id: RecordId) => DailyGuide | undefined;
  // すべての目標の1日の目安。並びは決めない
  findAll: () => DailyGuide[];
  // その目標の、その日から当てる1日の目安。目標を立てた・立て直したときの1日の目安は、当てる始まりの日が目標の開始の日のもの
  findByGoalAndEffectiveDay: (goalId: RecordId, effectiveOn: string) => DailyGuide | undefined;
  // 行を書くのは、目標を決めたことを書く口（writeGoalDecision）と週の見直しを書く口（writeWeeklyReview）だけにする
  insert: (dailyGuide: DailyGuide) => void;
};
