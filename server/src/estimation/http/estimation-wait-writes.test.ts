import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { createDishWrite } from "../../dish/http/testing/create-dish-write";
import { deleteDishWrite } from "../../dish/http/testing/delete-dish-write";
import { reestimateRenamedDish } from "../../dish/http/testing/reestimate-renamed-dish";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { requireLastSequence } from "../../http/sync-routes/testing/require-last-sequence";
import { signInTestAccount } from "../../http/testing";
import { updateIngredientWrite } from "../../ingredient/http/testing/update-ingredient-write";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { updateMealWrite } from "../../meal/http/testing/update-meal-write";
import { insertEstimationSchedule } from "../../meal-estimation-status/http/testing/insert-estimation-schedule";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { EstimationProviderBadRequestError } from "../domain/estimation-provider-bad-request-error";
import {
  mockCreateEstimationProviderError,
  mockCreateEstimationProviderOk,
} from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { insertCountedEstimations } from "./testing/insert-counted-estimations";
import { readEarliestCountedOn } from "./testing/read-earliest-counted-on";
import { recordEstimatedMeal } from "./testing/record-estimated-meal";
import { recordPhotographedMeal } from "./testing/record-photographed-meal";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";
import { beforeEach, describe, expect, test } from "vitest";

// 推定を待っている食事（写真を待っている・推定中・翌日に推定）では、料理を足すことと、料理と材料を直すことを断り、
// 時刻を直すことと、食事と料理を消すことは受け付ける（#381）
describe("推定を待っている食事への書き込み", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  let pushWrites: (writes: unknown[]) => Promise<PushResults["results"]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    pushWrites = async (writes) =>
      (await (await pushSyncWrites(sessionToken, { writes })).json<PushResults>()).results;
  });

  describe("写真を待っている食事のとき", () => {
    let mealId: string;
    let lastSequence: number;
    beforeEach(async () => {
      mealId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: generateRecordId() }] } })],
      });
      lastSequence = requireLastSequence(await pullChangesAfter(0));
    });

    describe("料理を足す書き込みを送ったとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        results = await pushWrites([createDishWrite(mealId)]);
      });

      test("推定を待っているとして受け付けず、今の値に無いことを添えること", () => {
        expect(results.map(toRejection)).toEqual([
          {
            result: "rejected",
            rejectionReason: "awaiting_estimation",
            current: { status: "absent" },
          },
        ]);
      });

      test("何も当てないこと", async () => {
        expect(await pullChangesAfter(lastSequence)).toEqual([]);
      });
    });

    describe("時刻を直す書き込みと、食事を消す書き込みを送ったとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        results = await pushWrites([
          updateMealWrite(mealId, Date.now() - 10 * 60_000),
          deleteMealWrite(mealId),
        ]);
      });

      test("どちらも当てたと返すこと", () => {
        expect(results.map(({ result }) => result)).toEqual(["applied", "applied"]);
      });
    });
  });

  describe("推定中の食事のとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
    });

    describe("料理を足す書き込みを送ったとき", () => {
      test("推定を待っているとして受け付けないこと", async () => {
        expect((await pushWrites([createDishWrite(mealId)])).map(toReason)).toEqual([
          "awaiting_estimation",
        ]);
      });
    });

    describe("推定が終わってから、料理を足す書き込みを送ったとき", () => {
      beforeEach(async () => {
        await runEstimationAlarm(accountId);
      });

      test("当てたと返すこと", async () => {
        expect((await pushWrites([createDishWrite(mealId)])).map(({ result }) => result)).toEqual([
          "applied",
        ]);
      });
    });
  });

  describe("翌日に推定の食事のとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      await insertCountedEstimations(accountId, await readEarliestCountedOn(accountId), 30);
      await runEstimationAlarm(accountId);
    });

    describe("料理を足す書き込みを送ったとき", () => {
      test("推定を待っているとして受け付けないこと", async () => {
        expect((await pushWrites([createDishWrite(mealId)])).map(toReason)).toEqual([
          "awaiting_estimation",
        ]);
      });
    });
  });

  describe("料理なしで推定が終わった食事に、料理を足す書き込みを送ったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderOk({ identifiedDishes: { dishes: [] } });
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("当てたと返すこと", async () => {
      expect((await pushWrites([createDishWrite(mealId)])).map(({ result }) => result)).toEqual([
        "applied",
      ]);
    });
  });

  describe("推定できなかった食事に、料理を足す書き込みを送ったとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mockCreateEstimationProviderError(
        new EstimationProviderBadRequestError({ errorType: "invalid_request_error" }),
      );
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
    });

    test("当てたと返すこと", async () => {
      expect((await pushWrites([createDishWrite(mealId)])).map(({ result }) => result)).toEqual([
        "applied",
      ]);
    });
  });

  // 料理のある食事が推定を待つことは、今の書き込みでは起きない（前の版で、待っている食事に足した料理）。
  // 推定できた食事に、まだ始めていない次の予定を直に足して、推定を待っている食事にする
  describe("料理のある食事が推定を待っているとき", () => {
    // 推定した親子丼（1 杯）と、その材料の鶏もも肉（80 g）
    let mealId: string;
    let dishId: string;
    let chickenId: string;
    let lastSequence: number;
    const awaitEstimation = async (progress: "waiting" | "deferred") => {
      await insertEstimationSchedule(accountId, mealId, {
        dueAt: Date.now() + 86_400_000,
        progress,
      });
      lastSequence = requireLastSequence(await pullChangesAfter(0));
    };
    beforeEach(async () => {
      mockCreateEstimationProviderOk();
      const estimated = await recordEstimatedMeal(accountId, sessionToken);
      mealId = estimated.mealId;
      dishId = estimated.dishId("親子丼");
      chickenId = estimated.ingredientId("鶏もも肉");
    });

    describe("推定中のとき", () => {
      beforeEach(async () => {
        await awaitEstimation("waiting");
      });

      describe("料理の名前を直す書き込みを送ったとき", () => {
        let results: PushResults["results"];
        beforeEach(async () => {
          results = await pushWrites([updateDishWrite(dishId, { name: "カツ丼" })]);
        });

        test("推定を待っているとして受け付けず、今の値に直す前の料理を添えること", () => {
          expect(
            results.map(({ result, rejectionReason, current }) => ({
              result,
              rejectionReason,
              status: current?.status,
              name: current?.change?.record["name"],
            })),
          ).toEqual([
            {
              result: "rejected",
              rejectionReason: "awaiting_estimation",
              status: "value",
              name: "親子丼",
            },
          ]);
        });

        test("何も当てないこと", async () => {
          expect(await pullChangesAfter(lastSequence)).toEqual([]);
        });
      });

      describe("範囲の外の名前に直す書き込みを送ったとき", () => {
        test("値の範囲より先に、推定を待っているとして受け付けないこと", async () => {
          expect(
            (await pushWrites([updateDishWrite(dishId, { name: " 　" })])).map(toReason),
          ).toEqual(["awaiting_estimation"]);
        });
      });

      describe("材料の量を直す書き込みを送ったとき", () => {
        let results: PushResults["results"];
        beforeEach(async () => {
          results = await pushWrites([updateIngredientWrite(chickenId, 120)]);
        });

        test("推定を待っているとして受け付けず、今の値に直す前の材料を添えること", () => {
          expect(
            results.map(({ result, rejectionReason, current }) => ({
              result,
              rejectionReason,
              status: current?.status,
              quantity: current?.change?.record["quantity"],
            })),
          ).toEqual([
            {
              result: "rejected",
              rejectionReason: "awaiting_estimation",
              status: "value",
              quantity: 80,
            },
          ]);
        });

        test("何も当てないこと", async () => {
          expect(await pullChangesAfter(lastSequence)).toEqual([]);
        });
      });

      describe("範囲の外の量に直す書き込みを送ったとき", () => {
        test("値の範囲より先に、推定を待っているとして受け付けないこと", async () => {
          expect((await pushWrites([updateIngredientWrite(chickenId, 0)])).map(toReason)).toEqual([
            "awaiting_estimation",
          ]);
        });
      });

      describe("時刻を直す書き込みと、料理を消す書き込みと、食事を消す書き込みを送ったとき", () => {
        test("どれも当てたと返すこと", async () => {
          expect(
            (
              await pushWrites([
                updateMealWrite(mealId, Date.now() - 10 * 60_000),
                deleteDishWrite(dishId),
                deleteMealWrite(mealId),
              ])
            ).map(({ result }) => result),
          ).toEqual(["applied", "applied", "applied"]);
        });
      });

      describe("本番のサーバーで、料理の名前を直す書き込みを送ったとき", () => {
        let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
        beforeEach(async () => {
          await enableUsageEventSending(accountId);
          captureSpy = mockPostHogCaptureEndpointOk();
          await pushWrites([updateDishWrite(dishId, { name: "カツ丼" })]);
        });

        test("受け付けなかった書き込みを、料理の種類と、推定を待っている理由で送ること", () => {
          expect(
            readPostHogCapturedEvents(captureSpy).filter(
              ({ event }) => event === "sync_write_rejected",
            ),
          ).toEqual([
            {
              event: "sync_write_rejected",
              distinct_id: accountId,
              properties: {
                write_kind: "update",
                record_type: "dish",
                reason: "awaiting_estimation",
                $geoip_disable: true,
              },
            },
          ]);
        });
      });
    });

    describe("翌日に推定のとき", () => {
      beforeEach(async () => {
        await awaitEstimation("deferred");
      });

      describe("料理の名前を直す書き込みと、材料の量を直す書き込みを送ったとき", () => {
        test("どちらも推定を待っているとして受け付けないこと", async () => {
          expect(
            (
              await pushWrites([
                updateDishWrite(dishId, { name: "カツ丼" }),
                updateIngredientWrite(chickenId, 120),
              ])
            ).map(toReason),
          ).toEqual(["awaiting_estimation", "awaiting_estimation"]);
        });
      });
    });

    describe("名前を直した推定し直しで材料が置き換わってから、推定中になったとき", () => {
      beforeEach(async () => {
        await pushWrites([updateDishWrite(dishId, { name: "カツ丼" })]);
        await reestimateRenamedDish(accountId, sessionToken, dishId);
        await awaitEstimation("waiting");
      });

      describe("前の材料の量を直す書き込みを送ったとき", () => {
        test("推定を待っているより先に、材料が置き換わっていたとして受け付けないこと", async () => {
          expect((await pushWrites([updateIngredientWrite(chickenId, 120)])).map(toReason)).toEqual(
            ["ingredients_replaced"],
          );
        });
      });

      describe("前の材料を載せて料理の量を直す書き込みを送ったとき", () => {
        test("推定を待っているより先に、材料が置き換わっていたとして受け付けないこと", async () => {
          expect(
            (
              await pushWrites([
                updateDishWrite(dishId, {
                  name: "カツ丼",
                  quantity: {
                    value: 2,
                    proportionedIngredients: [{ ingredientId: chickenId, quantity: 160 }],
                  },
                }),
              ])
            ).map(toReason),
          ).toEqual(["ingredients_replaced"]);
        });
      });
    });

    describe("消した料理を直す書き込みを送ったとき", () => {
      beforeEach(async () => {
        await awaitEstimation("waiting");
      });

      test("推定を待っているより先に、直す先が無いとして受け付けないこと", async () => {
        expect(
          (
            await pushWrites([deleteDishWrite(dishId), updateDishWrite(dishId, { name: "カツ丼" })])
          ).map(toReason),
        ).toEqual([undefined, "record_not_found"]);
      });
    });
  });
});

// 推定できた食事の中で、推定し直しを待っている料理（推定中・翌日に推定）では、その料理と材料を直すことを断り、
// その料理を消すことと、同じ食事のほかの料理を直すことと、料理を足すことは受け付ける（#381）。
// 写真の推定で、親子丼（1 杯。鶏もも肉 80 g）と緑茶ができた食事から始める
describe("推定し直しを待っている料理への書き込み", () => {
  let accountId: string;
  let sessionToken: string;
  let mealId: string;
  let dishId: string;
  let greenTeaId: string;
  let chickenId: string;
  let riceId: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  let pushWrites: (writes: unknown[]) => Promise<PushResults["results"]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    mockCreateEstimationProviderOk();
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    pushWrites = async (writes) =>
      (await (await pushSyncWrites(sessionToken, { writes })).json<PushResults>()).results;
    const estimated = await recordEstimatedMeal(accountId, sessionToken);
    mealId = estimated.mealId;
    dishId = estimated.dishId("親子丼");
    greenTeaId = estimated.dishId("緑茶");
    chickenId = estimated.ingredientId("鶏もも肉");
    riceId = estimated.ingredientId("ご飯");
  });

  describe("名前を直して推定し直し中のとき", () => {
    let lastSequence: number;
    beforeEach(async () => {
      await pushWrites([updateDishWrite(dishId, { name: "カツ丼" })]);
      lastSequence = requireLastSequence(await pullChangesAfter(0));
    });

    describe("その料理の量を直す書き込みを送ったとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        results = await pushWrites([
          updateDishWrite(dishId, {
            name: "カツ丼",
            quantity: {
              value: 2,
              proportionedIngredients: [
                { ingredientId: chickenId, quantity: 160 },
                { ingredientId: riceId, quantity: 400 },
              ],
            },
          }),
        ]);
      });

      test("推定を待っているとして受け付けず、今の値に直した名前の料理を添えること", () => {
        expect(
          results.map(({ result, rejectionReason, current }) => ({
            result,
            rejectionReason,
            status: current?.status,
            name: current?.change?.record["name"],
            quantity: current?.change?.record["quantity"],
          })),
        ).toEqual([
          {
            result: "rejected",
            rejectionReason: "awaiting_estimation",
            status: "value",
            name: "カツ丼",
            quantity: 1,
          },
        ]);
      });

      test("何も当てないこと", async () => {
        expect(await pullChangesAfter(lastSequence)).toEqual([]);
      });
    });

    describe("その料理の名前をまた直す書き込みを送ったとき", () => {
      test("推定を待っているとして受け付けないこと", async () => {
        expect(
          (await pushWrites([updateDishWrite(dishId, { name: "かつ丼" })])).map(toReason),
        ).toEqual(["awaiting_estimation"]);
      });
    });

    describe("その料理の材料の量を直す書き込みを送ったとき", () => {
      let results: PushResults["results"];
      beforeEach(async () => {
        results = await pushWrites([updateIngredientWrite(chickenId, 120)]);
      });

      test("推定を待っているとして受け付けず、今の値に直す前の材料を添えること", () => {
        expect(
          results.map(({ result, rejectionReason, current }) => ({
            result,
            rejectionReason,
            status: current?.status,
            quantity: current?.change?.record["quantity"],
          })),
        ).toEqual([
          {
            result: "rejected",
            rejectionReason: "awaiting_estimation",
            status: "value",
            quantity: 80,
          },
        ]);
      });

      test("何も当てないこと", async () => {
        expect(await pullChangesAfter(lastSequence)).toEqual([]);
      });
    });

    describe("ほかの料理の名前を直す書き込みと、料理を足す書き込みと、その料理を消す書き込みを送ったとき", () => {
      test("どれも当てたと返すこと", async () => {
        expect(
          (
            await pushWrites([
              updateDishWrite(greenTeaId, { name: "ほうじ茶" }),
              createDishWrite(mealId),
              deleteDishWrite(dishId),
            ])
          ).map(({ result }) => result),
        ).toEqual(["applied", "applied", "applied"]);
      });
    });

    describe("推定し直しが終わってから、その料理の名前と材料の量を直す書き込みを送ったとき", () => {
      let replacingIngredientIds: string[];
      beforeEach(async () => {
        replacingIngredientIds = await reestimateRenamedDish(accountId, sessionToken, dishId);
      });

      test("どちらも当てたと返すこと", async () => {
        const [replacingIngredientId] = replacingIngredientIds;
        if (replacingIngredientId === undefined) {
          throw new Error("置き換えた材料が無い");
        }
        expect(
          (
            await pushWrites([
              updateIngredientWrite(replacingIngredientId, 120),
              updateDishWrite(dishId, { name: "かつ丼" }),
            ])
          ).map(({ result }) => result),
        ).toEqual(["applied", "applied"]);
      });
    });
  });

  describe("名前を直した推定し直しが翌日に推定になったとき", () => {
    beforeEach(async () => {
      const countedOn = await readEarliestCountedOn(accountId);
      await pushWrites([updateDishWrite(dishId, { name: "カツ丼" })]);
      await insertCountedEstimations(accountId, countedOn, 29);
      await runEstimationAlarm(accountId);
    });

    describe("その料理の名前を直す書き込みと、材料の量を直す書き込みを送ったとき", () => {
      test("どちらも推定を待っているとして受け付けないこと", async () => {
        expect(
          (
            await pushWrites([
              updateDishWrite(dishId, { name: "かつ丼" }),
              updateIngredientWrite(chickenId, 120),
            ])
          ).map(toReason),
        ).toEqual(["awaiting_estimation", "awaiting_estimation"]);
      });
    });

    describe("その料理を消す書き込みを送ったとき", () => {
      test("当てたと返すこと", async () => {
        expect((await pushWrites([deleteDishWrite(dishId)])).map(({ result }) => result)).toEqual([
          "applied",
        ]);
      });
    });
  });

  describe("同じ要求で、料理を足し、その料理の名前を直す書き込みを送ったとき", () => {
    test("足す書き込みを当て、名前を直す書き込みを推定を待っているとして受け付けないこと", async () => {
      const create = createDishWrite(mealId, { name: "味噌汁" });
      expect(
        (await pushWrites([create, updateDishWrite(create.dishId, { name: "豚汁" })])).map(
          ({ result, rejectionReason }) => ({ result, rejectionReason }),
        ),
      ).toEqual([
        { result: "applied", rejectionReason: undefined },
        { result: "rejected", rejectionReason: "awaiting_estimation" },
      ]);
    });
  });
});

const toRejection = ({ result, rejectionReason, current }: PushResults["results"][number]) => ({
  result,
  rejectionReason,
  current,
});

const toReason = ({ rejectionReason }: PushResults["results"][number]) => rejectionReason;
