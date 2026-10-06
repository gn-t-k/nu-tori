import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { countCorrectionsByReceivedOrder } from "../../http/sync-routes/testing/count-corrections-by-received-order";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { updateIngredientWrite } from "../../ingredient/http/testing/update-ingredient-write";
import { updateMealWrite } from "../../meal/http/testing/update-meal-write";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { correctDishByWrites } from "./testing/correct-dish-by-writes";
import { deleteDishWrite } from "./testing/delete-dish-write";
import { insertDishWithoutQuantity } from "./testing/insert-dish-without-quantity";
import { updateDishWrite } from "./testing/update-dish-write";
import { inspectDeletedContents } from "./testing/inspect-deleted-contents";
import { reestimateRenamedDish } from "./testing/reestimate-renamed-dish";
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
      const [first, ...rest] = changesAfterDeletion;
      // 材料の削除の印どうしの並びは決めていない（材料の ID の順になる）
      expect({
        first: { kind: first?.kind, recordId: first?.recordId },
        rest: rest.map(({ kind, recordId }) => `${kind}:${recordId}`).toSorted(),
      }).toEqual({
        first: { kind: "dish_deletion", recordId: dishId },
        rest: ingredientIds.map((recordId) => `ingredient_deletion:${recordId}`).toSorted(),
      });
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

  describe("推定できた食事の料理を直すとき", () => {
    // 推定した親子丼（1 杯）と、その材料の鶏もも肉（80 g）とご飯（200 g）
    let mealId: string;
    let dishId: string;
    let chickenId: string;
    let riceId: string;
    let lastSequence: number;
    const quantityWrite = (value: number) =>
      updateDishWrite(dishId, {
        name: "親子丼",
        quantity: {
          value,
          proportionedIngredients: [
            { ingredientId: chickenId, quantity: 80 * value },
            { ingredientId: riceId, quantity: 200 * value },
          ],
        },
      });
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      const estimated = await pullChangesAfter(0);
      dishId = estimated.find(({ kind }) => kind === "dish")?.recordId ?? "";
      const ingredientIdNamed = (name: string) =>
        estimated.find(({ kind, record }) => kind === "ingredient" && record["name"] === name)
          ?.recordId ?? "";
      chickenId = ingredientIdNamed("鶏もも肉");
      riceId = ingredientIdNamed("ご飯");
      lastSequence = estimated.at(-1)?.sequence ?? 0;
    });

    describe("名前を2回直したとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        ({ results } = await (
          await pushSyncWrites(sessionToken, {
            writes: [
              updateDishWrite(dishId, { name: "カツ丼" }),
              updateDishWrite(dishId, { name: "かつ丼" }),
            ],
          })
        ).json<PushResults>());
      });

      test("どちらも当てたと返すこと", () => {
        expect(results.map(({ result }) => result)).toEqual(["applied", "applied"]);
      });

      test("取りに行くと、あとの名前と、名前の修正の数だけ上がった版の料理が返ること", async () => {
        expect(changedValues(await pullChangesAfter(lastSequence)).at(-1)).toEqual({
          kind: "dish",
          recordId: dishId,
          id: dishId,
          mealId,
          name: "かつ丼",
          quantity: 1,
          unit: "杯",
          quantitySource: "estimated",
          positionInMeal: 0,
          version: 3,
        });
      });
    });

    describe("量を、比例させた材料の量と一緒に直したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [
            updateDishWrite(dishId, {
              name: "親子丼",
              quantity: {
                value: 1.5,
                proportionedIngredients: [
                  { ingredientId: chickenId, quantity: 120 },
                  { ingredientId: riceId, quantity: 300 },
                ],
              },
            }),
          ],
        });
      });

      test("取りに行くと、直した量の料理と、比例させた量で出どころが推定のままの材料が返ること", async () => {
        expect(
          changedValues(await pullChangesAfter(lastSequence)).map(
            ({ kind, recordId, quantity, quantitySource, version }) => ({
              kind,
              recordId,
              quantity,
              quantitySource,
              version,
            }),
          ),
        ).toEqual([
          {
            kind: "dish",
            recordId: dishId,
            quantity: 1.5,
            quantitySource: "corrected",
            version: 2,
          },
          {
            kind: "ingredient",
            recordId: chickenId,
            quantity: 120,
            quantitySource: "estimated",
            version: undefined,
          },
          {
            kind: "ingredient",
            recordId: riceId,
            quantity: 300,
            quantitySource: "estimated",
            version: undefined,
          },
        ]);
      });

      describe("そのあとに材料の量を直したとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(chickenId, 100)] });
        });

        test("取りに行くと、材料を直した量が返ること", async () => {
          const chicken = changedValues(await pullChangesAfter(lastSequence)).findLast(
            ({ recordId }) => recordId === chickenId,
          );
          expect(chicken).toEqual(
            expect.objectContaining({ quantity: 100, quantitySource: "corrected" }),
          );
        });
      });
    });

    describe("時刻と名前と料理の量と材料の量を直す書き込みを当てたとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [updateMealWrite(mealId, Date.now() - 10 * 60_000)],
        });
        await correctDishByWrites(sessionToken, { dishId, ingredientIds: [chickenId, riceId] });
      });

      test("修正の表のどの行の控えにも、受け取った順（変更の並びとのつなぎ）があること", async () => {
        expect(await countCorrectionsByReceivedOrder(accountId)).toEqual({
          meal_eaten_at_corrections: { withOrder: 1, withoutOrder: 0 },
          dish_name_corrections: { withOrder: 2, withoutOrder: 0 },
          dish_quantity_corrections: { withOrder: 1, withoutOrder: 0 },
          ingredient_quantity_corrections: { withOrder: 1, withoutOrder: 0 },
        });
      });
    });

    describe("名前も量も今の値と同じ書き込みを送ったとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        ({ results } = await (
          await pushSyncWrites(sessionToken, {
            writes: [
              updateDishWrite(dishId, {
                name: "親子丼",
                quantity: {
                  value: 1,
                  proportionedIngredients: [
                    { ingredientId: chickenId, quantity: 80 },
                    { ingredientId: riceId, quantity: 200 },
                  ],
                },
              }),
            ],
          })
        ).json<PushResults>());
      });

      test("当てたと返すこと", () => {
        expect(results.map(({ result }) => result)).toEqual(["applied"]);
      });

      test("変更を足さないこと", async () => {
        expect(await pullChangesAfter(lastSequence)).toEqual([]);
      });
    });

    describe("受け付けない書き込みを送ったとき", () => {
      test("消した料理を直す書き込みは、直す先が無いとして、今の値に削除の印を添えること", async () => {
        expect(
          await pushRejection(sessionToken, [
            deleteDishWrite(dishId),
            updateDishWrite(dishId, { name: "カツ丼" }),
          ]),
        ).toEqual({ result: "rejected", rejectionReason: "record_not_found", status: "deleted" });
      });

      test("知らない料理を直す書き込みは、直す先が無いとして、今の値に無いことを添えること", async () => {
        expect(
          await pushRejection(sessionToken, [
            updateDishWrite(crypto.randomUUID(), { name: "カツ丼" }),
          ]),
        ).toEqual({ result: "rejected", rejectionReason: "record_not_found", status: "absent" });
      });

      test("空白だけの名前は、範囲の外として、今の値に料理を添えること", async () => {
        expect(
          await pushRejection(sessionToken, [updateDishWrite(dishId, { name: " 　" })]),
        ).toEqual({
          result: "rejected",
          rejectionReason: "out_of_range",
          status: "value",
        });
      });

      test("量が 0 の書き込みは、範囲の外とすること", async () => {
        expect(
          await pushRejection(sessionToken, [
            updateDishWrite(dishId, {
              name: "親子丼",
              quantity: {
                value: 0,
                proportionedIngredients: [
                  { ingredientId: chickenId, quantity: 0 },
                  { ingredientId: riceId, quantity: 0 },
                ],
              },
            }),
          ]),
        ).toEqual({ result: "rejected", rejectionReason: "out_of_range", status: "value" });
      });

      test("比例させた材料の量が 0 の書き込みは、範囲の外とすること", async () => {
        expect(
          await pushRejection(sessionToken, [
            updateDishWrite(dishId, {
              name: "親子丼",
              quantity: {
                value: 0.5,
                proportionedIngredients: [
                  { ingredientId: chickenId, quantity: 0 },
                  { ingredientId: riceId, quantity: 100 },
                ],
              },
            }),
          ]),
        ).toEqual({ result: "rejected", rejectionReason: "out_of_range", status: "value" });
      });
    });

    describe("量の無い料理があるとき", () => {
      let quantitylessDishId: string;
      beforeEach(async () => {
        quantitylessDishId = await insertDishWithoutQuantity(accountId, mealId, "味噌汁");
      });

      test("量を載せた書き込みは、範囲の外として受け付けないこと", async () => {
        const response = await pushSyncWrites(sessionToken, {
          writes: [
            updateDishWrite(quantitylessDishId, {
              name: "味噌汁",
              quantity: { value: 1, proportionedIngredients: [] },
            }),
          ],
        });
        expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "out_of_range",
        );
      });

      describe("量を省いて名前だけを直す書き込みを送ったとき", () => {
        let results: PushResults["results"];
        beforeEach(async () => {
          ({ results } = await (
            await pushSyncWrites(sessionToken, {
              writes: [updateDishWrite(quantitylessDishId, { name: "豚汁" })],
            })
          ).json<PushResults>());
        });

        test("当てたと返すこと", () => {
          expect(results.map(({ result }) => result)).toEqual(["applied"]);
        });

        test("取りに行くと、量と単位と量の出どころを省いた、直した名前の料理が返ること", async () => {
          expect(changedValues(await pullChangesAfter(lastSequence))).toEqual([
            {
              kind: "dish",
              recordId: quantitylessDishId,
              id: quantitylessDishId,
              mealId,
              name: "豚汁",
              positionInMeal: 0,
              version: 2,
            },
            // 名前を直したので、推定し直しを待つ
            {
              kind: "dish_estimation_status",
              recordId: quantitylessDishId,
              dishId: quantitylessDishId,
              status: "estimating",
            },
          ]);
        });
      });
    });

    describe("本番のサーバーで", () => {
      let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
      beforeEach(async () => {
        await enableUsageEventSending(accountId);
        fetchSpy = mockPostHogCaptureEndpointOk();
      });

      describe("推定した料理の量を直したとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, { writes: [quantityWrite(1.5)] });
        });

        test("料理を直した率だけを PostHog に送り、比例させた材料は送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
            {
              event: "estimated_quantity_corrected",
              distinct_id: accountId,
              properties: { target: "dish", meal_input: "photo", ratio: 1.5, $geoip_disable: true },
            },
          ]);
        });

        describe("直した料理の量をもう一度直したとき", () => {
          beforeEach(async () => {
            fetchSpy.mockClear();
            await pushSyncWrites(sessionToken, { writes: [quantityWrite(2)] });
          });

          test("送らないこと", () => {
            expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
          });
        });

        describe("比例させた材料の量を直したとき", () => {
          beforeEach(async () => {
            fetchSpy.mockClear();
            await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(riceId, 250)] });
          });

          test("比例させたあとの量に対する率を送ること", () => {
            expect(
              readPostHogCapturedEvents(fetchSpy).map(({ properties }) => properties["ratio"]),
            ).toEqual([250 / 300]);
          });
        });
      });

      describe("名前だけを直したとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, {
            writes: [updateDishWrite(dishId, { name: "カツ丼" })],
          });
        });

        test("送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
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
      const corrected = await pushSyncWrites(sessionToken, {
        writes: [
          updateMealWrite(mealId, Date.now() - 10 * 60_000),
          updateMealWrite(mealId, Date.now() - 20 * 60_000),
        ],
      });
      if (
        (await corrected.json<PushResults>()).results.some(({ result }) => result !== "applied")
      ) {
        throw new Error("時刻を直す書き込みが当たらなかった");
      }
      // 名前を2回直すので、1回目の名前で待った予定は、2回目の名前の書き込みが取り消す
      await correctDishByWrites(sessionToken, { dishId, ingredientIds: previousIngredientIds });
      const replacingIngredientIds = await reestimateRenamedDish(accountId, sessionToken, dishId);
      ingredientIds = [...previousIngredientIds, ...replacingIngredientIds];
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

      test("取りに行くと、料理と、前の推定の材料も含むすべての材料と、料理ごとの推定の状態の削除の印が返ること", async () => {
        const changes = (await pullChangesAfter(lastSequence)).map(({ kind, recordId }) => ({
          kind,
          recordId,
        }));
        const [dishChange] = changes;
        // 材料どうしの並びは約束しない（消す口が材料を引く順は ID の並びに左右される）
        expect({
          dish: dishChange,
          ingredients: changes
            .slice(1, -1)
            .toSorted((a, b) => a.recordId.localeCompare(b.recordId)),
          status: changes.at(-1),
        }).toEqual({
          dish: { kind: "dish_deletion", recordId: dishId },
          ingredients: ingredientIds
            .toSorted((a, b) => a.localeCompare(b))
            .map((recordId) => ({ kind: "ingredient_deletion", recordId })),
          status: { kind: "dish_estimation_status_deletion", recordId: dishId },
        });
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

// 取りに行った変更を、種類・記録の ID と値の欄を並べた1つの値にする
const changedValues = (changes: PullResult["changes"]) =>
  changes.map(({ kind, recordId, record }): Record<string, unknown> => ({
    kind,
    recordId,
    ...record,
  }));

// 書き込みを送り、最後の書き込みの結果を返す
const pushRejection = async (sessionToken: string, writes: unknown[]) => {
  const { results } = await (await pushSyncWrites(sessionToken, { writes })).json<PushResults>();
  const last = results.at(-1);
  return {
    result: last?.result,
    rejectionReason: last?.rejectionReason,
    status: last?.current?.status,
  };
};
