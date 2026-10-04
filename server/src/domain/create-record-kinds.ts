import { createAccountSettingsKind } from "../account-settings/domain/create-account-settings-kind";
import { createDishKind } from "../dish/domain/create-dish-kind";
import { createIngredientKind } from "../ingredient/domain/create-ingredient-kind";
import { createMealKind } from "../meal/domain/create-meal-kind";
import { createMealEstimationStatusKind } from "../meal-estimation-status/domain/create-meal-estimation-status-kind";
import { createNoticeKind } from "../notice/domain/create-notice-kind";
import { createUsualWeighingTimeKind } from "../usual-weighing-time/domain/create-usual-weighing-time-kind";
import { createWeightRecordKind } from "../weight-record/domain/create-weight-record-kind";
import { createWeightTrendKind } from "../weight-trend/domain/create-weight-trend-kind";
import { findLatestValidTimeZone } from "./find-latest-valid-time-zone";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordKind } from "./sync-ledger/record-kind";
import type { WriteBase } from "./sync-ledger/write-base";

// 種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）。
// ほかの種類から計算する種類は、元の種類の書き込みを当てたあとに、この順で呼ばれる。receivedAt は要求を受け取った時刻
export const createRecordKinds = (stores: RecordKindStores, receivedAt: Date) =>
  [
    createAccountSettingsKind(stores.accountSettings),
    createDishKind(stores.dish),
    createIngredientKind(stores.ingredient),
    createMealKind(stores, receivedAt),
    createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus),
    createNoticeKind(stores.notice),
    createUsualWeighingTimeKind({
      store: stores.usualWeighingTime,
      weightRecordStore: stores.weightRecord,
      findLatestTimeZone: () => findLatestValidTimeZone(stores.latestTimeZone),
      receivedAt,
    }),
    createWeightRecordKind({
      store: stores.weightRecord,
      findStartedOn: stores.firstSignIn.findStartedOn,
    }),
    createWeightTrendKind(stores.weightRecord),
  ] as const satisfies readonly RecordKind<string, WriteBase, unknown, string, string>[];
