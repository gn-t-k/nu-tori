import type { EstimationAttemptResult } from "../estimation/domain/estimation-attempt-result";
import type { TokenUsage } from "../estimation/domain/estimation-provider";
import type { IngredientNutrientSource } from "../ingredient/domain/ingredient";
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
      // 推定し終えた・諦めたとき。推定中に食事・料理を消したときは、食事・料理を消す書き込みで送る
      name: "estimation_ended";
      // 推定のきっかけ。写真の推定（食事が対象）と、名前を直した・料理を足したときの推定し直し（料理が対象）
      trigger: "photo" | "dish_renamed" | "dish_added";
      // 料理が対象の推定は、料理ごとの推定の状態の値（estimated・no_dishes・failed）で送る。
      // 推定中に消えたら、消えたものの区分（食事・料理）で送る
      finalStatus: "estimated" | "no_dishes" | "failed" | "meal_deleted" | "dish_deleted";
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
      // 1日の回数の上限に達していて、予定を次の日に回したとき
      name: "estimation_deferred";
    }
  | {
      name: "sync_pending_writes_reported";
      pendingWriteCount: number;
      oldestPendingWriteAgeSeconds: number;
    }
  | {
      // 推定し直しを当てた料理を、使う人がまた直した・消したとき（#332 の「観測」）。「元に戻す」が要るかを見る
      name: "reestimated_dish_edited";
      action: "corrected" | "deleted";
      // 料理に当てたいちばん新しい推定し直しの終わり（完了か断念）から、直す・消す書き込みを当てるまで
      secondsFromReestimationEnded: number;
    }
  | {
      // 量の出どころが推定の料理・材料の量を直す書き込みを当てたとき（量の修正の率。#332 の「観測」）
      name: "estimated_quantity_corrected";
      target: "dish" | "ingredient";
      // 写真の食事か文章の食事か。文章の食事は「文章と会話」で足すので、今は写真だけでも送る
      mealInput: "photo";
      // 材料のときだけ持つ
      ingredientNutrientSource: IngredientNutrientSource["type"] | undefined;
      // 直した量 ÷ 推定の量（直す前の今の量。比例で変えた材料では比例のあとの量）
      ratio: number;
    };
