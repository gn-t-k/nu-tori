import { createAccountSettingsKind } from "../account-settings/domain/create-account-settings-kind";
import { createDishKind } from "../dish/domain/create-dish-kind";
import { createIngredientKind } from "../ingredient/domain/create-ingredient-kind";
import { createMealKind } from "../meal/domain/create-meal-kind";
import { createMealEstimationStatusKind } from "../meal-estimation-status/domain/create-meal-estimation-status-kind";
import { createNoticeKind } from "../notice/domain/create-notice-kind";
import { createWeightRecordKind } from "../weight-record/domain/create-weight-record-kind";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordKind } from "./sync-ledger/record-kind";
import type { WriteBase } from "./sync-ledger/write-base";

// 種類の登録簿。名前の順に、手で1行ずつ書く（生成しない）。ここにある種類は帳簿の道、無い種類は今の道で当てる。
// receivedAt は要求を受け取った時刻
export const createRecordKinds = (stores: RecordKindStores, receivedAt: Date) =>
  [
    createAccountSettingsKind(stores.accountSettings),
    createDishKind(stores.dish),
    createIngredientKind(stores.ingredient),
    createMealKind(stores, receivedAt),
    createMealEstimationStatusKind(stores.meal, stores.mealEstimationStatus),
    createNoticeKind(stores.notice),
    createWeightRecordKind(stores.weightRecord, stores.firstSignIn.findStartedOn),
  ] as const satisfies readonly RecordKind<string, WriteBase, unknown, string>[];
