import type { RecordChangeWrites } from "../../domain/record-change-writes";
import type { RecordId } from "../../domain/record-id";
import type { GoalStore } from "./goal-store";
import type { GoalAchievement, GoalDeadlineConfirmation } from "./goal";

// 目標の経過（達成と期限の日の確定）を書く口。記録の変化を書く入口（RecordChangeWriter）の run の中で呼び、
// 書いた目標の記録を足す（達成も確定も、同じ目標の変更がもう一度届く）。
// 表で守らない決まり（減量・増量の目標だけ、1つの目標に1回だけ、達成は閉じていない目標だけで、確定のあとは期限の日より後の日だけ）は、
// 書く前にここで確かめて投げる。減量・増量の目標だけであることは外部キーも保つ
export const writeGoalAchievement = (
  goalStore: GoalStore,
  addChange: RecordChangeWrites["addChange"],
  { goalId, achievement }: { goalId: RecordId; achievement: GoalAchievement },
): void => {
  const goal = goalStore.find(goalId);
  if (goal?.weightChange === undefined) {
    throw new Error("達成を書く目標が、減量・増量の目標ではない");
  }
  if (goal.achievement !== undefined) {
    throw new Error("達成した目標に、達成をもう一度書こうとした");
  }
  if (goal.closure !== undefined) {
    throw new Error("閉じた目標に達成を書こうとした");
  }
  if (
    goal.deadlineConfirmation !== undefined &&
    achievement.achievedOn <= goal.weightChange.deadlineOn
  ) {
    throw new Error("期限の日の結果を確定したあとに、期限の日以前の日を達成した日にしようとした");
  }
  goalStore.insertAchievement({ ...achievement, goalId });
  addChange({ recordType: "goal", recordId: goalId });
};

export const writeGoalDeadlineConfirmation = (
  goalStore: GoalStore,
  addChange: RecordChangeWrites["addChange"],
  { goalId, confirmation }: { goalId: RecordId; confirmation: GoalDeadlineConfirmation },
): void => {
  const goal = goalStore.find(goalId);
  if (goal?.weightChange === undefined) {
    throw new Error("期限の日を確定する目標が、減量・増量の目標ではない");
  }
  if (goal.deadlineConfirmation !== undefined) {
    throw new Error("期限の日を確定した目標を、もう一度確定しようとした");
  }
  goalStore.insertDeadlineConfirmation({ ...confirmation, goalId });
  addChange({ recordType: "goal", recordId: goalId });
};
