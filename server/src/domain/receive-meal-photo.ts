import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { scheduleMealEstimation } from "../estimation/domain/schedule-meal-estimation";
import type { MealPhotoArchive } from "../meal/domain/meal-photo-archive";
import type { MealPhotoStore } from "../meal/domain/meal-photo-store";
import type { RecordChangeWriter } from "./record-change-writer";
import type { RecordId } from "./record-id";
import type { RecordKindStores } from "./record-kind-stores";

// 写真のファイルを R2 に置き、受け取りを控える。同じ写真が再び届いたときと、消した食事の写真が届いたときは、何もせずに受け取った形で終える。
// 食事の写真がこれでそろったら、記録の変化を書く入口を通して推定の予定に入れる。
// 数の上限を超えた写真は置かずに断る。食事が先に宣言した写真は、待っている数に入れない。
// 失敗は、呼び出し側が状態コードを変え、PostHog と要求ごとのログに失敗した段を出すために、Result で返す
export const receiveMealPhoto = (
  writeRecordChanges: RecordChangeWriter,
  stores: MealPhotoReceiptStores,
  archive: MealPhotoArchive,
  request: { photoId: RecordId; photo: ArrayBuffer; receivedAt: Date },
): R.ResultAsync<void, MealPhotoLimitExceededError | MealPhotoReceiptFailedError> => {
  const { photoId, receivedAt } = request;
  if (stores.mealPhoto.hasReceipt(photoId) || stores.mealPhoto.hasDeletion(photoId)) {
    return Promise.resolve(R.succeed());
  }
  if (exceedsLimit(stores.mealPhoto, photoId, receivedAt)) {
    return Promise.resolve(R.fail(new MealPhotoLimitExceededError()));
  }
  // R2 はトランザクションに入らないので、置いてから控える。置いているあいだに食事が消えたら、控えたあとに消し残しとして消す
  return R.pipe(
    R.try({
      try: () => archive.put(photoId, request.photo),
      catch: (cause) => new MealPhotoReceiptFailedError({ stage: "put_file", cause }),
    }),
    R.andThen(() =>
      R.try({
        try: () => recordReceipt(writeRecordChanges, stores, photoId, receivedAt),
        catch: (cause) => new MealPhotoReceiptFailedError({ stage: "record_receipt", cause }),
      }),
    ),
  );
};

export class MealPhotoLimitExceededError extends ErrorFactory({
  name: "MealPhotoLimitExceededError",
  message: "受け取れる写真の数の上限を超えた",
}) {}

// stage は失敗した段。受け口の要求ごとのログと、PostHog の出来事に載せる
export class MealPhotoReceiptFailedError extends ErrorFactory({
  name: "MealPhotoReceiptFailedError",
  message: "写真を受け取れなかった",
  fields: ErrorFactory.fields<{ stage: "put_file" | "record_receipt" }>(),
}) {}

type MealPhotoReceiptStores = Pick<
  RecordKindStores,
  "estimationSchedule" | "latestTimeZone" | "meal" | "mealPhoto"
>;

// 置いているあいだに並んで届いた要求は数に入らないので、その分だけ超えることがある
const exceedsLimit = (store: MealPhotoStore, photoId: RecordId, receivedAt: Date): boolean => {
  // ふつうの使い方の多いほう（1日に6食を4枚ずつで24枚、電波の無かった1週間の分を一度に送って168枚）が届かない数にする
  const maximumReceiptsPerDay = 300;
  // 食事より先に着いた分だけの上限。超えた分は端末が送り直し、食事が届いたあとは数に入らないので通る
  const maximumUndeclaredReceipts = 100;
  const dayMilliseconds = 24 * 60 * 60 * 1000;
  if (
    store.countReceiptsAfter(new Date(receivedAt.getTime() - dayMilliseconds)) >=
    maximumReceiptsPerDay
  ) {
    return true;
  }
  return (
    store.findMealIdOfPhoto(photoId) === undefined &&
    store.findUndeclaredReceipts().length >= maximumUndeclaredReceipts
  );
};

const recordReceipt = (
  writeRecordChanges: RecordChangeWriter,
  stores: MealPhotoReceiptStores,
  photoId: RecordId,
  receivedAt: Date,
): void => {
  writeRecordChanges(({ estimation }) => {
    // 同じ写真の要求が、置いているあいだに先に控えたかもしれない
    if (stores.mealPhoto.hasReceipt(photoId)) {
      return;
    }
    stores.mealPhoto.insertReceipt(photoId, receivedAt);
    const mealId = stores.mealPhoto.findMealIdOfPhoto(photoId);
    const meal = mealId === undefined ? undefined : stores.meal.find(mealId);
    if (meal !== undefined) {
      scheduleMealEstimation(stores, estimation, meal, receivedAt);
    }
  });
};
