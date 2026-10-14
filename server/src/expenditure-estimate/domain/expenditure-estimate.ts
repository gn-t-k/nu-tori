import type { RecordId } from "../../domain/record-id";

// 推定消費カロリーの推定。ID はサーバーが振る
export type ExpenditureEstimate = {
  id: RecordId;
  // 当てる始まりの日（YYYY-MM-DD）
  effectiveOn: string;
  expenditureKcal: number;
  estimatedAt: Date;
  // 推定の始まりだけが持つ出どころ
  initialSource: InitialExpenditureSource | undefined;
};

// 推定の始まりの出どころ。逆算と式
export const initialExpenditureSources = ["back_calculated", "formula"] as const;

export type InitialExpenditureSource = (typeof initialExpenditureSources)[number];
