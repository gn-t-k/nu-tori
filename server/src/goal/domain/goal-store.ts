import type { RecordId } from "../../domain/record-id";
import type { Goal } from "./goal";

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
  // 行を書くのは、目標を決めたことを書く口（writeGoalDecision）だけにする。表をまたぐ決まりは口が確かめる
  insert: (goal: Omit<Goal, "closure">) => void;
  insertClosure: (closure: { goalId: RecordId; nextGoalId: RecordId }) => void;
  insertDecisionReceipt: (receipt: { requestId: string; goalId: RecordId }) => void;
};
