import { advanceEstimations } from "../estimation/domain/advance-estimations";
import type { EstimationProvider } from "../estimation/domain/estimation-provider";
import { deleteLeftoverMealPhotoFiles } from "../meal/domain/delete-leftover-meal-photo-files";
import type { MealPhotoArchive } from "../meal/domain/meal-photo-archive";
import { computeNextAlarmAt } from "./compute-next-alarm-at";
import { computeNextAlarmAtExceptLeftoverPhotos } from "./compute-next-alarm-at-except-leftover-photos";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordType } from "./record-type";
import type { LedgerStore } from "./sync-ledger/ledger-store";

// 呼び出し側は、次の時刻に張り、提供元のエラーを Sentry に送り、利用状況を送り、error があれば投げて Cloudflare のアラームのやり直しに任せる
export const runAccountAlarm = async (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  deps: {
    archive: MealPhotoArchive;
    provider: EstimationProvider;
    armAlarm: () => Promise<void>;
  },
) => {
  const advanced = await advanceEstimations(ledgerStore, stores, deps, new Date());
  const deletionError: unknown = await deleteLeftoverMealPhotoFiles(
    stores.mealPhoto,
    deps.archive,
    new Date(),
  ).then(
    () => undefined,
    (error: unknown) => error,
  );
  return {
    // 消し直しに失敗したら、今に張り直さず Cloudflare のアラームのやり直しに任せる。使い切ったら、次に予定を入れたときに消し直す
    nextAlarmAt:
      deletionError === undefined
        ? computeNextAlarmAt(stores, new Date())
        : computeNextAlarmAtExceptLeftoverPhotos(stores),
    // 推定が止まったことを、消し直しの失敗より先に報告する
    error: advanced.stoppedError ?? deletionError,
    providerErrors: advanced.providerErrors,
    usageEvents: advanced.usageEvents,
    attempts: advanced.attempts,
  };
};
