import type { RecordChangeWrites } from "../../domain/record-change-writes";
import type { RecordId } from "../../domain/record-id";
import type { GoalStore } from "./goal-store";
import type { GoalDeadlineConfirmation } from "./goal";

// 期限の日の確定を書く口。記録の変化を書く入口（RecordChangeWriter）の run の中で呼び、書いた目標の記録を足す（同じ目標の変更がもう一度届く）。
// 表で守らない決まり（減量・増量の目標だけ、1つの目標に1回だけ）は、書く前にここで確かめて投げる。減量・増量の目標だけであることは外部キーも保つ
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
