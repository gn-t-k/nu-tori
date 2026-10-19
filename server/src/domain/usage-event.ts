import type { EstimationAttemptOutcome } from "../estimation/domain/estimation-attempt-outcome";
import type { TokenUsage } from "./token-usage";
import type { IngredientNutrientSource } from "../ingredient/domain/ingredient";
import type { MealEntryMethod } from "../meal/domain/meal-entry-method";
import type { MealPhotoReceiptFailedError } from "./receive-meal-photo";
import type { DailyGuideLimitType, DailyGuideMainReason } from "../daily-guide/domain/daily-guide";
import type { InitialExpenditureSource } from "../expenditure-estimate/domain/expenditure-estimate";
import type { GoalDirection } from "../goal/domain/goal-direction";
import type { PacePlan } from "../goal/domain/goal";
import type { ClassificationLabel } from "../reply/domain/conversation-provider";
import type { ReplyAttemptOutcome } from "../reply/domain/reply-attempt-outcome";
import type { SentTextClassification } from "../sent-text/domain/sent-text-classification";
import type { WeeklyReviewDeferralReason } from "../weekly-review/domain/weekly-review";
import type { ReplyFailureReason } from "../sent-text-status/domain/sent-text-status";
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
      result: EstimationAttemptOutcome["result"];
      identifyDishesUsage: TokenUsage | undefined;
      matchIngredientsUsage: TokenUsage | undefined;
    }
  | {
      // 推定し終えた・諦めたとき。推定中に食事・料理を消したときは、食事・料理を消す書き込みで送る
      name: "estimation_ended";
      // 推定のきっかけ。写真の推定と文章の食事の推定（食事が対象）と、名前を直した・料理を足したときの推定し直し（料理が対象）
      trigger: "photo" | "text" | "dish_renamed" | "dish_added";
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
      // 送った文章を読み分けたとき（呼び出しごと）。本文は含めない
      name: "sent_text_classified";
      // 書いた読み分けの結果。決めかねたときと呼び出しの失敗は会話
      result: SentTextClassification;
      // 提供元の答え。呼び出しが失敗したら failed
      providerResult: ClassificationLabel | "failed";
      // 呼び出しで使ったトークン。失敗したら undefined
      usage: TokenUsage | undefined;
      // 送った文章を作る書き込みを受け取ってから、読み分けを書くまで
      secondsFromReceivedToClassified: number;
      // 呼び出しが失敗したときの、提供元のエラーの種類
      providerErrorType: string | undefined;
    }
  | {
      // 返事の試みの結果を書いたとき（呼び出しごと）。本文は含めない
      name: "reply_attempt_ended";
      result: ReplyAttemptOutcome["result"];
      // 呼び出しで使ったトークン。分からなければ undefined
      usage: TokenUsage | undefined;
      // 提供元のエラーと 400 のときの、提供元のエラーの種類
      providerErrorType: string | undefined;
    }
  | {
      // 返事を書いた・作れなかったにしたとき（生成ごと）。本文は含めない
      name: "reply_generation_ended";
      finalStatus: "replied" | "failed";
      // 作れなかった理由。返事を書いたら undefined
      failureReason: ReplyFailureReason | undefined;
      // 自動のやり直しの回数（試みの数 - 1）
      retryCount: number;
      // 返事が指し示した食事の数
      referencedMealCount: number;
      // 返事の依頼を作ってから（読み分けた・送り直しを受け取った）、終えるまで
      secondsFromRequestedToEnded: number;
      // 試みで提供元が返したエラーの種類（重ねない）
      providerErrorTypes: string[];
    }
  | {
      // 1日の返事の回数の上限に達していて、提供元を呼ばずに依頼を回数切れにしたとき。1日 20 回を調整するのに見る
      name: "reply_request_halted";
    }
  | {
      // 1日の回数の上限に達していて、予定を次の日に回したとき
      name: "estimation_deferred";
    }
  | {
      // 目標を決めたとき（初めてと立て直し）。同じ要求の ID の再送では送らない。体重・目標体重・kcal の値は含めない
      name: "goal_decision_recorded";
      direction: GoalDirection;
      // 初めての目標か。false は立て直し
      isFirstGoal: boolean;
      chosenPlan: PacePlan | "maintain";
      // 1日の目安が下限を下回らないよう、速さを落とした案があったか
      hadSlowedProposal: boolean;
      // 端末が数えて要求に載せた、受け付けなかった自分の目標体重の数
      rejectedCustomTargetWeightCount: number;
      // 推定消費カロリーの出どころ。立て直しは前の値
      expenditureSource: InitialExpenditureSource | "previous";
      limitHits: DailyGuideLimitType[];
    }
  | {
      // 週の見直し（見送りを含む）を書いたとき（週ごと）。出荷後に k と見送る条件を調整するのに見る。
      // 体重・kcal の値は含めず、推定消費カロリーは差だけを送る
      name: "weekly_review";
      // 見送った理由。見直せた週は undefined
      deferralReason: WeeklyReviewDeferralReason | undefined;
      // 見直せた週の1日の目安が当たった上限と下限。見送った週は空
      limitHits: DailyGuideLimitType[];
      // 見直せた週だけ
      mainReason: DailyGuideMainReason | undefined;
      // 見直した推定 − 前の推定（kcal）。見送った週は undefined
      expenditureChangeKcal: number | undefined;
      initialExpenditureSource: InitialExpenditureSource | undefined;
      // 推定の始まりのあとの 4 回めと 8 回めの見直し（見送りを含む）だけ、そのときの推定 − 推定の始まり（kcal）
      expenditureChangeFromInitialKcal: number | undefined;
      // 同じ要求でまとめて見直した週の数
      reviewedWeekCount: number;
    }
  | {
      // 減量・増量の目標の達成を書いたとき。体重・目標体重の値は含めない
      name: "goal_achieved";
      // 開始の日から達成した日までの日数
      daysFromStart: number;
      // 達成した日から期限の日までの日数。期限のあとに達成したらマイナス
      daysUntilDeadline: number;
    }
  | {
      // 減量・増量の目標の期限の日の結果を確定したとき。体重・目標体重の値は含めない
      name: "goal_deadline_confirmed";
      // 期限の日の体重の傾向 − 目標体重（kg、0.1 kg 単位）
      differenceFromTargetKg: number;
      // 確定したときに達成していたか
      achieved: boolean;
    }
  | {
      // 期限後の維持に移ったとき
      name: "goal_moved_to_maintenance";
      // 期限の日から、維持に移った月曜までの日数
      daysAfterDeadline: number;
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
  | ({
      // 量の出どころが推定の料理・材料の量を直す書き込みを当てたとき（量の修正の率。#332 の「観測」）
      name: "estimated_quantity_corrected";
      // 写真の食事か文章の食事か。文章の食事は「文章と会話」で足すので、今は写真だけでも送る
      mealInput: "photo";
      // 直した量 ÷ 推定の量（直す前の今の量。比例で変えた材料では比例のあとの量）
      ratio: number;
    } & (
      | { target: "dish" }
      | { target: "ingredient"; ingredientNutrientSource: IngredientNutrientSource["type"] }
    ));
