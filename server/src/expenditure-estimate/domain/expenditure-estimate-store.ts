import type { RecordId } from "../../domain/record-id";
import type { ExpenditureEstimate } from "./expenditure-estimate";

export type ExpenditureEstimateStore = {
  find: (id: RecordId) => ExpenditureEstimate | undefined;
  // 当てる始まりの日がその日（YYYY-MM-DD）以前の推定。並びは決めない
  findEffectiveOnOrBefore: (calendarDay: string) => ExpenditureEstimate[];
  // 今の推定（当てる始まりの日が最も遅いもの）。初めて目標を立てる前は無い
  findCurrent: () => ExpenditureEstimate | undefined;
  // 行を書くのは、目標を決めたことを書く口（writeGoalDecision）だけにする。推定の始まりが1つであることは口が確かめる
  insert: (estimate: ExpenditureEstimate) => void;
};
