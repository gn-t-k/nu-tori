import { createAccountSettingsKind } from "../account-settings/domain/create-account-settings-kind";
import { createAiUtteranceKind } from "../ai-utterance/domain/create-ai-utterance-kind";
import { createDailyGuideKind } from "../daily-guide/domain/create-daily-guide-kind";
import { createDishKind } from "../dish/domain/create-dish-kind";
import { createDishEstimationStatusKind } from "../dish-estimation-status/domain/create-dish-estimation-status-kind";
import { createExpenditureEstimateKind } from "../expenditure-estimate/domain/create-expenditure-estimate-kind";
import { createGoalKind } from "../goal/domain/create-goal-kind";
import { createIngredientKind } from "../ingredient/domain/create-ingredient-kind";
import { createMealKind } from "../meal/domain/create-meal-kind";
import { createMealEstimationStatusKind } from "../meal-estimation-status/domain/create-meal-estimation-status-kind";
import { createNoticeKind } from "../notice/domain/create-notice-kind";
import { createSentTextKind } from "../sent-text/domain/create-sent-text-kind";
import { createSentTextStatusKind } from "../sent-text-status/domain/create-sent-text-status-kind";
import { createSubscriptionStatusKind } from "../subscription-status/domain/create-subscription-status-kind";
import { createUsualWeighingTimeKind } from "../usual-weighing-time/domain/create-usual-weighing-time-kind";
import { createWeeklyReviewKind } from "../weekly-review/domain/create-weekly-review-kind";
import { createWeightRecordKind } from "../weight-record/domain/create-weight-record-kind";
import { createWeightTrendKind } from "../weight-trend/domain/create-weight-trend-kind";
import { findLatestValidTimeZone } from "./find-latest-valid-time-zone";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordType } from "./record-type";
import type { RecordKind } from "./sync-ledger/record-kind";
import type { WriteBase } from "./sync-ledger/write-base";

// 種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）。名前の一覧（record-types.ts）に無い名前の種類と、一覧にあるのにここに無い種類は、型検査が止める。
// ほかの種類から計算する種類は、元の種類の書き込みを当てたあとに、この順で呼ばれる。receivedAt は要求を受け取った時刻
export const createRecordKinds = (stores: RecordKindStores, receivedAt: Date) =>
  coveringRecordTypes([
    createAccountSettingsKind(stores.accountSettings),
    createAiUtteranceKind(stores.aiUtterance),
    createDailyGuideKind(stores.dailyGuide),
    createDishKind(stores, receivedAt),
    createDishEstimationStatusKind(stores.dish, stores.dishEstimationStatus, receivedAt),
    createExpenditureEstimateKind(stores.expenditureEstimate),
    createGoalKind(stores.goal),
    createIngredientKind(stores, receivedAt),
    createMealKind(stores, receivedAt),
    createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus),
    createNoticeKind(stores.notice),
    createSentTextKind(stores, receivedAt),
    createSentTextStatusKind(stores.sentText, stores.sentTextStatus),
    createSubscriptionStatusKind(stores.subscriptionStatus),
    createUsualWeighingTimeKind({
      store: stores.usualWeighingTime,
      weightRecordStore: stores.weightRecord,
      findLatestTimeZone: () => findLatestValidTimeZone(stores.latestTimeZone),
      receivedAt,
    }),
    createWeeklyReviewKind(stores.weeklyReview),
    createWeightRecordKind({
      store: stores.weightRecord,
      findStartedOn: stores.firstSignIn.findStartedOn,
    }),
    createWeightTrendKind(stores.weightRecord),
  ] as const satisfies readonly RecordKind<RecordType, WriteBase, unknown, string, string>[]);

// 一覧のすべての種類が並びにあることを、型で確かめる。足りないと引数の型が never になり、呼ぶ側の型検査が落ちる。並びはそのまま返す
const coveringRecordTypes = <TKinds extends readonly { name: string }[]>(
  kinds: TKinds & (RecordType extends TKinds[number]["name"] ? unknown : never),
): TKinds => kinds;
