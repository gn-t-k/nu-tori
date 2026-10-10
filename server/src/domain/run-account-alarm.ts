import { advanceEstimations } from "../estimation/domain/advance-estimations";
import type { EstimationProvider } from "../estimation/domain/estimation-provider";
import { deleteLeftoverMealPhotoFiles } from "../meal/domain/delete-leftover-meal-photo-files";
import type { MealPhotoArchive } from "../meal/domain/meal-photo-archive";
import { advanceReplies } from "../reply/domain/advance-replies";
import type { ConversationProvider } from "../reply/domain/conversation-provider";
import type { ReplyWatchers } from "../reply/domain/create-reply-watchers";
import { classifySentTexts } from "../sent-text/domain/classify-sent-texts";
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
    conversationProvider: ConversationProvider;
    armAlarm: () => Promise<void>;
    replyWatchers: ReplyWatchers;
  },
) => {
  // 食事と読み分けた文章の推定を、同じアラームで始めるため、推定より先に読み分ける
  const classified = await classifySentTexts(ledgerStore, stores, {
    provider: deps.conversationProvider,
  });
  // 食事と読み分けた文章の見守る要求を閉じる
  deps.replyWatchers.refresh(stores);
  const advanced = await advanceEstimations(ledgerStore, stores, deps, new Date());
  // 推定のあとに作り、同じアラームで推定し終えた食事の栄養を返事の文脈に入れる
  const replied = await advanceReplies(
    ledgerStore,
    stores,
    {
      provider: deps.conversationProvider,
      armAlarm: deps.armAlarm,
      watchers: deps.replyWatchers,
    },
    new Date(),
  );
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
    // 推定・返事が止まったことを、消し直しの失敗より先に報告する
    error: advanced.stoppedError ?? replied.stoppedError ?? deletionError,
    providerErrors: [
      ...classified.providerErrors,
      ...advanced.providerErrors,
      ...replied.providerErrors,
    ],
    usageEvents: [...classified.usageEvents, ...advanced.usageEvents, ...replied.usageEvents],
    classifications: classified.classifications,
    attempts: advanced.attempts,
    replyAttempts: replied.attempts,
  };
};
