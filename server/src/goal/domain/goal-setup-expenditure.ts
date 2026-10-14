import type { RecordId } from "../../domain/record-id";
import type { InitialExpenditureSource } from "../../expenditure-estimate/domain/expenditure-estimate";

// 目標の設定に使う推定消費カロリー。初めての目標では逆算か式で出し、立て直すときは今の推定を使う
export type GoalSetupExpenditure =
  | { source: InitialExpenditureSource; kcal: number }
  | { source: "current"; kcal: number; expenditureEstimateId: RecordId };
