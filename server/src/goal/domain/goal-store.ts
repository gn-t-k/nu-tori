import type { RecordId } from "../../domain/record-id";
import type { DecidedGoal, Goal, GoalAchievement, GoalDeadlineConfirmation } from "./goal";

export type GoalStore = {
  find: (id: RecordId) => Goal | undefined;
  // すべての目標（閉じた目標を含む）。並びは決めない
  findAll: () => Goal[];
  // 今の目標（閉じていない目標）。初めて目標を立てる前は無い
  findCurrent: () => Goal | undefined;
  // その目標を次の目標にして閉じた、前の目標。初めての目標には無い
  findClosedBy: (nextGoalId: RecordId) => Goal | undefined;
  // 目標を決める要求の受け取りが指す目標。受け取っていない要求には無い
  findByDecisionRequest: (requestId: string) => Goal | undefined;
  // 目標と閉じる行を書くのは、目標を決めたことを書く口（writeGoalDecision）と、期限後の維持に移る週の見直しを書く口（writeWeeklyReview）だけにする。
  // 達成と期限の日の確定を書くのは、達成を書く口（write-goal-achievement.ts）と期限の日の確定を書く口（write-goal-deadline-confirmation.ts）だけにする。表をまたぐ決まりは口が確かめる
  insert: (goal: DecidedGoal) => void;
  insertClosure: (closure: { goalId: RecordId; nextGoalId: RecordId }) => void;
  insertDecisionReceipt: (receipt: { requestId: string; goalId: RecordId }) => void;
  // 期限後の維持の目標のサブセット。目標の行のあとに書く
  insertPostDeadlineMaintenance: (goalId: RecordId) => void;
  insertAchievement: (achievement: GoalAchievement & { goalId: RecordId }) => void;
  insertDeadlineConfirmation: (
    confirmation: GoalDeadlineConfirmation & { goalId: RecordId },
  ) => void;
};
