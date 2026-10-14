import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { Goal } from "./goal";
import type { GoalStore } from "./goal-store";

// 目標の種類。サーバーだけが書き、閉じた目標も残るので消えない
export const createGoalKind = (store: GoalStore): RecordKind<"goal", never, Goal> =>
  createServerOnlyKind({ name: "goal", whenGone: "never", find: store.find });
