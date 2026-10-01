import type { MealEntryMethod } from "../meal/domain/meal-entry-method";
import type { RecordType } from "./record-type";
import type { RejectionReason } from "./rejection-reason";
import type { WriteKind } from "./sync-ledger/write-kind";

export type UsageEvent =
  | {
      name: "sync_write_rejected";
      writeKind: WriteKind;
      recordType: RecordType;
      reason: RejectionReason;
    }
  | {
      name: "meal_received";
      entryMethod: MealEntryMethod;
      minutesFromEatenToSent: number;
      // 食べた日の、消していない食事のうち何回目に受け取ったか
      mealCountOfDay: number;
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    };
