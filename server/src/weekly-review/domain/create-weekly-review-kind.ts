import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { WeeklyReview } from "./weekly-review";
import type { WeeklyReviewStore } from "./weekly-review-store";

// 週の見直しの種類。サーバーだけが書き、書き足すだけなので消えない
export const createWeeklyReviewKind = (
  store: WeeklyReviewStore,
): RecordKind<"weekly_review", never, WeeklyReview> =>
  createServerOnlyKind({ name: "weekly_review", whenGone: "never", find: store.find });
