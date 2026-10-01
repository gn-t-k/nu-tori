import type { EstimationAttemptResult } from "../estimation/domain/estimation-attempt-result";
import type { TokenUsage } from "../estimation/domain/estimation-provider";
import type { MealEntryMethod } from "../meal/domain/meal-entry-method";
import type { MealPhotoReceiptFailedError } from "./receive-meal-photo";
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
      name: "meal_photo_receipt_failed";
      stage: MealPhotoReceiptFailedError["stage"];
    }
  | {
      // 試みの結果を書いたとき。① が通って ② で落ちた試みも、① のトークンを送る
      name: "estimation_attempt_ended";
      result: EstimationAttemptResult;
      identifyDishesUsage: TokenUsage | undefined;
      matchIngredientsUsage: TokenUsage | undefined;
    }
  | {
      // 推定し終えた・諦めたとき。推定中に食事を消したときは、食事を消す書き込みで送る
      name: "estimation_ended";
      trigger: "photo";
      finalStatus: "estimated" | "no_dishes" | "failed" | "meal_deleted";
      // 自動のやり直しの回数（試みの数 - 1）
      retryCount: number;
      dishCount: number;
      ingredientCount: number;
      // 材料の栄養の出どころの内訳（材料の数）
      nutritionLabelIngredientCount: number;
      foodCompositionIngredientCount: number;
      estimatedIngredientCount: number;
      secondsFromReceivedToEnded: number;
      // 試みで提供元が返したエラーの種類（重ねない）
      providerErrorTypes: string[];
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    };
