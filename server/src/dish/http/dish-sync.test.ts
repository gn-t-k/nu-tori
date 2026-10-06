import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import { deleteDishWrite } from "./testing/delete-dish-write";
import { inspectDeletedContents } from "./testing/inspect-deleted-contents";
import { seedNotYetWritableEdits } from "./testing/seed-not-yet-writable-edits";
import { beforeEach, describe, expect, test } from "vitest";

describe("料理の同期", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
  });

  describe("推定できた食事の料理を消す書き込みを送ったとき", () => {
    let dishId: string;
    let ingredientIds: string[];
    let write: ReturnType<typeof deleteDishWrite>;
    let results: PushResults["results"];
    let changesAfterDeletion: PullResult["changes"];
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      const estimated = await pullChangesAfter(0);
      dishId = estimated.find(({ kind }) => kind === "dish")?.recordId ?? "";
      ingredientIds = estimated
        .filter(({ kind, record }) => kind === "ingredient" && record["dishId"] === dishId)
        .map(({ recordId }) => recordId);
      const lastSequence = estimated.at(-1)?.sequence ?? 0;
      write = deleteDishWrite(dishId);
      ({ results } = await (
        await pushSyncWrites(sessionToken, { writes: [write] })
      ).json<PushResults>());
      changesAfterDeletion = await pullChangesAfter(lastSequence);
    });

    test("当てたと返すこと", () => {
      expect(results).toEqual([{ writeId: write.id, result: "applied" }]);
    });

    test("取りに行くと、料理とその材料の削除の印が返ること", () => {
      expect(changesAfterDeletion.map(({ kind, recordId }) => ({ kind, recordId }))).toEqual([
        { kind: "dish_deletion", recordId: dishId },
        ...ingredientIds.map((recordId) => ({ kind: "ingredient_deletion", recordId })),
      ]);
    });
  });
  describe("知らない ID の料理を消す書き込みを送ったとき", () => {
    let dishId: string;
    let write: ReturnType<typeof deleteDishWrite>;
    let results: PushResults["results"];
    beforeEach(async () => {
      dishId = crypto.randomUUID();
      write = deleteDishWrite(dishId);
      ({ results } = await (
        await pushSyncWrites(sessionToken, { writes: [write] })
      ).json<PushResults>());
    });

    test("受け付けなかったとせず、当てたと返すこと", () => {
      expect(results).toEqual([{ writeId: write.id, result: "applied" }]);
    });

    test("消した書き込みの控えつきで、料理の削除の印を残すこと", async () => {
      expect(
        await readRows(
          accountId,
          `SELECT r.kind, r.record_type, r.record_id FROM dish_deletions AS d
           JOIN sync_write_receipts AS r ON r.id = d.sync_write_receipt_id WHERE d.dish_id = '${dishId}'`,
        ),
      ).toEqual([{ kind: "delete", record_type: "dish", record_id: dishId }]);
    });

    test("取りに行くと、料理の削除の印が返ること", async () => {
      expect(
        (await pullChangesAfter(0)).map(({ kind, recordId, record }) => ({
          kind,
          recordId,
          record,
        })),
      ).toEqual([{ kind: "dish_deletion", recordId: dishId, record: {} }]);
    });

    describe("同じ料理をもう一度消す書き込みを送ったとき", () => {
      test("削除の印のある料理として捨てること", async () => {
        const response = await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(dishId)] });
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_tombstone");
      });
    });
  });

  describe("時刻と名前と量と材料を直し、推定し直しで材料が置き換わり、待つ予定を取り消した料理と、直していない料理があるとき", () => {
    let mealId: string;
    let dishId: string;
    let untouchedDishId: string;
    // 前の推定の材料と、置き換えた材料
    let ingredientIds: string[];
    let untouchedIngredientIds: string[];
    let lastSequence: number;
    let estimationCountsBefore: { estimationSchedules: number; estimations: number };
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      const estimated = await pullChangesAfter(0);
      const dishIds = estimated
        .filter(({ kind }) => kind === "dish")
        .map(({ recordId }) => recordId);
      dishId = dishIds[0] ?? "";
      untouchedDishId = dishIds[1] ?? "";
      const ingredientIdsOf = (id: string) =>
        estimated
          .filter(({ kind, record }) => kind === "ingredient" && record["dishId"] === id)
          .map(({ recordId }) => recordId);
      const previousIngredientIds = ingredientIdsOf(dishId);
      untouchedIngredientIds = ingredientIdsOf(untouchedDishId);
      const { replacingIngredientId } = await seedNotYetWritableEdits(accountId, {
        mealId,
        dishId,
        ingredientId: previousIngredientIds[0] ?? "",
      });
      ingredientIds = [...previousIngredientIds, replacingIngredientId];
      lastSequence = (await pullChangesAfter(0)).at(-1)?.sequence ?? 0;
      const { estimationSchedules, estimations } = await inspectDeletedContents(accountId, {
        mealIds: [],
        dishIds: [],
        ingredientIds: [],
      });
      estimationCountsBefore = { estimationSchedules, estimations };
    });

    describe("直した料理を消す書き込みを送ったとき", () => {
      let write: ReturnType<typeof deleteDishWrite>;
      let results: PushResults["results"];
      let inspected: Awaited<ReturnType<typeof inspectDeletedContents>>;
      beforeEach(async () => {
        write = deleteDishWrite(dishId);
        ({ results } = await (
          await pushSyncWrites(sessionToken, { writes: [write] })
        ).json<PushResults>());
        inspected = await inspectDeletedContents(accountId, {
          mealIds: [],
          dishIds: [dishId],
          ingredientIds,
        });
      });

      test("当てたと返すこと", () => {
        expect(results).toEqual([{ writeId: write.id, result: "applied" }]);
      });

      test("取りに行くと、料理と、前の推定の材料も含むすべての材料の削除の印が返ること", async () => {
        const changes = await pullChangesAfter(lastSequence);
        expect(changes.map(({ kind, recordId }) => ({ kind, recordId }))).toEqual([
          { kind: "dish_deletion", recordId: dishId },
          ...ingredientIds.map((recordId) => ({ kind: "ingredient_deletion", recordId })),
        ]);
      });

      test("控えを外部キーで指す表のうち、削除の印と帳簿のほかに、消した料理と材料の控えから辿れる行が残らないこと", () => {
        expect({
          // 数え上げが修正の表を拾っていること
          countsCorrectionTables: [
            "dish_name_corrections",
            "dish_quantity_corrections",
            "ingredient_quantity_corrections",
            "estimation_schedule_cancellations",
          ].every((table) => inspected.tablesReferringToReceipts.includes(table)),
          leftoverRowsByTable: inspected.leftoverRowsByTable,
        }).toEqual({ countsCorrectionTables: true, leftoverRowsByTable: {} });
      });

      test("当てた推定・推定の量・材料・栄養・比例の明細・つなぎ・取り消しが残らないこと", () => {
        expect(inspected.contentCounts).toEqual({
          dishes: 0,
          estimationApplications: 0,
          estimatedQuantities: 0,
          ingredients: 0,
          ingredientNutrients: 0,
          foodCompositionIngredients: 0,
          proportions: 0,
          dishScheduleLinks: 0,
          cancellationsOfLinkedSchedules: 0,
          meals: 0,
        });
      });

      test("料理と、前の推定の材料も含むすべての材料の削除の印を、消した書き込みの控えつきで書くこと", () => {
        const receipt = { kind: "delete", recordType: "dish", recordId: dishId };
        expect({
          dishes: inspected.dishDeletionReceipts,
          ingredients: inspected.ingredientDeletionReceipts,
        }).toEqual({
          dishes: { [dishId]: receipt },
          ingredients: Object.fromEntries(ingredientIds.map((id) => [id, receipt])),
        });
      });

      test("予定と推定は残ること", () => {
        expect({
          estimationSchedules: inspected.estimationSchedules,
          estimations: inspected.estimations,
        }).toEqual(estimationCountsBefore);
      });

      test("外部キーの違反が無いこと", () => {
        expect(inspected.foreignKeyViolations).toEqual([]);
      });

      test("直していない料理とその材料は残ること", async () => {
        const untouched = await inspectDeletedContents(accountId, {
          mealIds: [mealId],
          dishIds: [untouchedDishId],
          ingredientIds: untouchedIngredientIds,
        });
        expect({
          dishes: untouched.contentCounts.dishes,
          ingredients: untouched.contentCounts.ingredients,
          meals: untouched.contentCounts.meals,
        }).toEqual({ dishes: 1, ingredients: untouchedIngredientIds.length, meals: 1 });
      });
    });
  });
});
