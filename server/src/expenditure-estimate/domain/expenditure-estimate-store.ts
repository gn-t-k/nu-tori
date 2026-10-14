import type { RecordId } from "../../domain/record-id";
import type { ExpenditureEstimate } from "./expenditure-estimate";

export type ExpenditureEstimateStore = {
  find: (id: RecordId) => ExpenditureEstimate | undefined;
  // 今の推定（当てる始まりの日が最も遅いもの）。初めて目標を立てる前は無い
  findCurrent: () => ExpenditureEstimate | undefined;
};
