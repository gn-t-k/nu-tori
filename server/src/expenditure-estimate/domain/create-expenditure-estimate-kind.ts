import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { ExpenditureEstimate } from "./expenditure-estimate";
import type { ExpenditureEstimateStore } from "./expenditure-estimate-store";

// 推定消費カロリーの種類。サーバーだけが書き、書き足すだけなので消えない
export const createExpenditureEstimateKind = (
  store: ExpenditureEstimateStore,
): RecordKind<"expenditure_estimate", never, ExpenditureEstimate> =>
  createServerOnlyKind({ name: "expenditure_estimate", whenGone: "never", find: store.find });
