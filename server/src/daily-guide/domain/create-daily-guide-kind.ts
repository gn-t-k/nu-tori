import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { DailyGuide } from "./daily-guide";
import type { DailyGuideStore } from "./daily-guide-store";

// 1日の目安の種類。サーバーだけが書き、書き足すだけなので消えない
export const createDailyGuideKind = (
  store: DailyGuideStore,
): RecordKind<"daily_guide", never, DailyGuide> =>
  createServerOnlyKind({ name: "daily_guide", whenGone: "never", find: store.find });
