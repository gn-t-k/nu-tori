import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { deleteDishWrite } from "../../dish/http/testing/delete-dish-write";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordEstimatedMeal } from "../../estimation/http/testing/record-estimated-meal";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { beforeEach, describe, expect, test } from "vitest";

// 状態の移り変わり（推定中から各状態、翌日に推定、名前をまた直して推定中）は、推定し直しのテスト（estimation/http/dish-reestimation.test.ts）で確かめる
describe("料理ごとの推定の状態の同期", () => {
  let sessionToken: string;
  let mealId: string;
  let renamedDishId: string;
  let pullStatusChanges: () => Promise<{ kind: string; recordId: string }[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    let accountId: string;
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    mockCreateEstimationProviderOk();
    const estimated = await recordEstimatedMeal(accountId, sessionToken);
    mealId = estimated.mealId;
    renamedDishId = estimated.dishId("親子丼");
    pullStatusChanges = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter(({ kind }) => kind.startsWith("dish_estimation_status"))
        .map(({ kind, recordId }) => ({ kind, recordId }));
  });

  test("推定し直しをしていない料理は、値を持たず、変更も届かないこと", async () => {
    expect(await pullStatusChanges()).toEqual([]);
  });

  describe("2つの料理のうち1つの名前を直したとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [updateDishWrite(renamedDishId, { name: "カツ丼" })],
      });
    });

    test("名前を直した料理の状態だけが届くこと", async () => {
      expect(await pullStatusChanges()).toEqual([
        { kind: "dish_estimation_status", recordId: renamedDishId },
      ]);
    });

    test("名前を直した料理を消すと、料理の削除の印から状態の削除の印が届くこと", async () => {
      await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(renamedDishId)] });
      expect(await pullStatusChanges()).toEqual([
        { kind: "dish_estimation_status_deletion", recordId: renamedDishId },
      ]);
    });

    test("食事を消すと、予定のある料理の分だけ状態の削除の印が届くこと", async () => {
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
      expect(await pullStatusChanges()).toEqual([
        { kind: "dish_estimation_status_deletion", recordId: renamedDishId },
      ]);
    });
  });
});
