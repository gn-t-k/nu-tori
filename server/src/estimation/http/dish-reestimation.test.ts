import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { createDishWrite } from "../../dish/http/testing/create-dish-write";
import { deleteDishWrite } from "../../dish/http/testing/delete-dish-write";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { requireLastSequence } from "../../http/sync-routes/testing/require-last-sequence";
import { signInTestAccount } from "../../http/testing";
import { updateIngredientWrite } from "../../ingredient/http/testing/update-ingredient-write";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import {
  mockCreateEstimationProviderError,
  mockCreateEstimationProviderOk,
} from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { readIdentifyDishesRequests } from "./testing/read-identify-dishes-requests";
import { EstimationProviderBadRequestError } from "../domain/estimation-provider-bad-request-error";
import { insertCountedEstimations } from "./testing/insert-counted-estimations";
import { recordEstimatedMeal } from "./testing/record-estimated-meal";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";
import { waitForEstimationAttempts } from "./testing/wait-for-estimation-attempts";
import { beforeEach, describe, expect, test } from "vitest";

// 名前を直したときの推定し直し（#332 の「推定し直し」）。写真の推定で、親子丼（1 杯。鶏もも肉 80 g・ご飯 200 g）と緑茶ができた食事から始める
describe("名前を直したときの推定し直し", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let provider: ReturnType<typeof mockCreateEstimationProviderOk>;
  let mealId: string;
  let dishId: string;
  let chickenId: string;
  let riceId: string;
  let lastSequence: number;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult["changes"]>;
  // 推定し直しの料理への変更を、種類・記録の ID・値の欄を並べた形で返す
  let pullDishChanges: () => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    provider = mockCreateEstimationProviderOk();
    const estimated = await recordEstimatedMeal(accountId, sessionToken);
    ({ mealId, lastSequence } = estimated);
    dishId = estimated.dishId("親子丼");
    chickenId = estimated.ingredientId("鶏もも肉");
    riceId = estimated.ingredientId("ご飯");
    pullChangesAfter = async (afterSequence) =>
      (await (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>()).changes;
    pullDishChanges = async () =>
      (await pullChangesAfter(lastSequence)).map(({ kind, recordId, record }) => ({
        kind,
        recordId,
        ...record,
      }));
  });

  // 偽の時計は止まっているので、出来事の時刻（予定の時刻、推定の終わり）が前の出来事と同じにならないよう進めてから送る
  const rename = async (name: string) => {
    clock.advance(1000);
    const { results } = await (
      await pushSyncWrites(sessionToken, { writes: [updateDishWrite(dishId, { name })] })
    ).json<PushResults>();
    if (results.some(({ result }) => result !== "applied")) {
      throw new Error(`名前を直す書き込みが当たらなかった: ${JSON.stringify(results)}`);
    }
  };
  const currentIngredientNamesOfDish = async () =>
    (await pullChangesAfter(0))
      .filter(({ kind, record }) => kind === "ingredient" && record["dishId"] === dishId)
      .map(({ record }) => `${String(record["name"])} ${String(record["quantity"])}`)
      .toSorted();
  const readDishSchedules = () =>
    readRows(
      accountId,
      `SELECT s.due_at, s.counted_on,
              (SELECT count(*) FROM estimation_schedule_cancellations c WHERE c.estimation_schedule_id = s.id) AS cancelled,
              (SELECT count(*) FROM estimations e WHERE e.estimation_schedule_id = s.id) AS started
       FROM estimation_schedules s JOIN dish_estimation_schedules d ON d.estimation_schedule_id = s.id
       WHERE d.dish_id = '${dishId}' ORDER BY s.due_at`,
    );

  describe("推定した料理の名前を直す書き込みを当てたとき", () => {
    beforeEach(async () => {
      await rename("カツ丼");
    });

    test("書き込みを受け取った時刻の、その日の分として数える予定を足すこと", async () => {
      expect(await readDishSchedules()).toEqual([
        {
          due_at: Date.now(),
          counted_on: new Date(Date.now() + 9 * 3_600_000).toISOString().slice(0, 10),
          cancelled: 0,
          started: 0,
        },
      ]);
    });

    test("取りに行くと、直した名前の料理のあとに、料理ごとの推定の状態が推定中で届くこと", async () => {
      expect(
        (await pullDishChanges()).map(({ kind, name, status }) => ({ kind, name, status })),
      ).toEqual([
        { kind: "dish", name: "カツ丼", status: undefined },
        { kind: "dish_estimation_status", name: undefined, status: "estimating" },
      ]);
    });

    describe("アラームで推定し直したとき", () => {
      let alarmRan: boolean;
      let previousIngredientIds: string[];
      beforeEach(async () => {
        previousIngredientIds = [chickenId, riceId];
        alarmRan = await runEstimationAlarm(accountId);
      });

      test("アラームを予定の時刻に張っていること", () => {
        expect(alarmRan).toBe(true);
      });

      test("① に、食事の写真と料理の今の名前を渡し、直した材料と量は渡さないこと", () => {
        const request = readIdentifyDishesRequests(provider).at(-1);
        expect({ photoCount: request?.photos.length, target: request?.target }).toEqual({
          photoCount: 1,
          target: {
            type: "dish",
            dish: { name: "カツ丼", correctedIngredients: [], correctedQuantity: undefined },
          },
        });
      });

      test("推定し直しも、その日の推定の回数に数えること", async () => {
        expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(2);
      });

      test("取りに行くと、届いた量と、推定を当てた数だけ上がった版の料理、新しい材料、前の材料の削除の印、推定できたの状態の順に届くこと", async () => {
        // 取りに行く応答は、記録ごとにいちばんあとの変更だけを返す
        const [dishChange, ...rest] = await pullDishChanges();
        expect({
          dish: dishChange,
          // 材料どうしの並びは約束しない
          ingredients: rest
            .slice(0, -1)
            .map(({ kind, name, quantity, recordId }) =>
              kind === "ingredient_deletion"
                ? `ingredient_deletion ${previousIngredientIds.indexOf(String(recordId))}`
                : `${String(kind)} ${String(name)} ${String(quantity)}`,
            )
            .toSorted(),
          last: rest.at(-1),
        }).toEqual({
          dish: {
            kind: "dish",
            recordId: dishId,
            id: dishId,
            mealId,
            name: "カツ丼",
            quantity: 1,
            unit: "杯",
            quantitySource: "estimated",
            positionInMeal: 0,
            // 1 ＋ 名前の修正 ＋ 推定し直しを当てた数
            version: 3,
          },
          ingredients: [
            "ingredient ご飯 200",
            "ingredient 鶏もも肉 80",
            "ingredient_deletion 0",
            "ingredient_deletion 1",
          ],
          last: {
            kind: "dish_estimation_status",
            recordId: dishId,
            dishId,
            status: "estimated",
          },
        });
      });

      test("前の材料の行は、前の推定に属したまま残ること", async () => {
        expect(
          await readRows(
            accountId,
            `SELECT count(*) AS total FROM ingredients WHERE id IN ('${chickenId}', '${riceId}')`,
          ),
        ).toEqual([{ total: 2 }]);
      });

      describe("推定し直しで材料が置き換わったあとに、届くのが遅れた書き込みを送ったとき", () => {
        let results: PushResults["results"];
        const pushLateWrite = async (write: unknown) => {
          ({ results } = await (
            await pushSyncWrites(sessionToken, { writes: [write] })
          ).json<PushResults>());
        };

        describe("前の材料を載せた料理の量の書き込みのとき", () => {
          beforeEach(async () => {
            await pushLateWrite(
              updateDishWrite(dishId, {
                name: "カツ丼",
                quantity: {
                  value: 1.5,
                  proportionedIngredients: [
                    { ingredientId: chickenId, quantity: 120 },
                    { ingredientId: riceId, quantity: 300 },
                  ],
                },
              }),
            );
          });

          test("材料が置き換わったとして、今の値に料理の今の値を添えること", () => {
            expect({
              result: results[0]?.result,
              rejectionReason: results[0]?.rejectionReason,
              status: results[0]?.current?.status,
              record: results[0]?.current?.change?.record,
            }).toEqual({
              result: "rejected",
              rejectionReason: "ingredients_replaced",
              status: "value",
              record: expect.objectContaining({ name: "カツ丼", quantity: 1, version: 3 }),
            });
          });
        });

        describe("量が今と同じで、前の材料を載せた料理の書き込みのとき", () => {
          beforeEach(async () => {
            await pushLateWrite(
              updateDishWrite(dishId, {
                name: "カツカレー",
                quantity: {
                  value: 1,
                  proportionedIngredients: [
                    { ingredientId: chickenId, quantity: 80 },
                    { ingredientId: riceId, quantity: 200 },
                  ],
                },
              }),
            );
          });

          test("材料が置き換わったとして受け付けないこと", () => {
            expect({
              result: results[0]?.result,
              rejectionReason: results[0]?.rejectionReason,
            }).toEqual({ result: "rejected", rejectionReason: "ingredients_replaced" });
          });
        });

        describe("量を省いて名前だけを直す書き込みのとき", () => {
          beforeEach(async () => {
            await pushLateWrite(updateDishWrite(dishId, { name: "カツカレー" }));
          });

          test("受け付けること", () => {
            expect(results[0]?.result).toBe("applied");
          });
        });

        describe("前の材料の量を直す書き込みのとき", () => {
          beforeEach(async () => {
            await pushLateWrite(updateIngredientWrite(riceId, 150));
          });

          test("材料が置き換わったとして、今の値に削除の印を添えること", () => {
            expect({
              result: results[0]?.result,
              rejectionReason: results[0]?.rejectionReason,
              status: results[0]?.current?.status,
            }).toEqual({
              result: "rejected",
              rejectionReason: "ingredients_replaced",
              status: "deleted",
            });
          });
        });
      });
    });
  });

  describe("料理と材料の量を直してから名前を直したとき", () => {
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
          updateIngredientWrite(riceId, 250),
        ],
      });
      // 量を固定しても、提供元が別の量を答えることがある
      provider = mockCreateEstimationProviderOk({
        identifiedDishes: ({ target }) => ({
          dishes: [
            {
              name: target.type === "dish" ? target.dish.name : "",
              quantity: 3,
              unit: "皿",
              ingredients: [
                {
                  name: "豚ロース",
                  quantity: 150,
                  unit: "g",
                  edibleGramsPerUnit: 1,
                  foodCompositionQuery: "ぶた ロース 脂身つき 焼き",
                  nutritionLabel: undefined,
                },
                {
                  name: "ご飯",
                  quantity: 250,
                  unit: "g",
                  edibleGramsPerUnit: 1,
                  foodCompositionQuery: "こめ 水稲めし 精白米",
                  nutritionLabel: undefined,
                },
              ],
            },
          ],
        }),
      });
      await rename("カツ丼");
      await runEstimationAlarm(accountId);
    });

    test("① に、直した材料だけを名前と量の組で渡し、直した料理の量と単位を渡すこと", () => {
      expect(readIdentifyDishesRequests(provider).at(-1)?.target).toEqual({
        type: "dish",
        dish: {
          name: "カツ丼",
          // 比例で変えた鶏もも肉は渡さない
          correctedIngredients: [{ name: "ご飯", quantity: 250, unit: "g" }],
          correctedQuantity: { value: 1.5, unit: "杯" },
        },
      });
    });

    test("料理の量は届いた量を当てず、直した量のままにし、材料は届いた材料に置き換えること", async () => {
      const dish = (await pullDishChanges()).findLast(({ kind }) => kind === "dish");
      expect({
        dish: {
          quantity: dish?.["quantity"],
          unit: dish?.["unit"],
          source: dish?.["quantitySource"],
        },
        ingredients: await currentIngredientNamesOfDish(),
      }).toEqual({
        dish: { quantity: 1.5, unit: "杯", source: "corrected" },
        // 届いた材料の量の出どころは、渡した直した材料と同じでも推定したまま
        ingredients: ["ご飯 250", "豚ロース 150"],
      });
    });
  });

  describe("推定し直しの呼び出し中に", () => {
    let reply: () => void;
    let alarm: Promise<boolean>;
    beforeEach(async () => {
      const { promise: replyAfter, resolve } = Promise.withResolvers<void>();
      reply = resolve;
      provider = mockCreateEstimationProviderOk({ replyAfter });
      await rename("カツ丼");
      alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 2);
    });

    describe("料理の量を直したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [
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
          ],
        });
        reply();
        await alarm;
      });

      test("当てるときの今の量を見て、直した量を固定し、材料だけを当てること", async () => {
        const dish = (await pullDishChanges()).findLast(({ kind }) => kind === "dish");
        expect({
          dish: { quantity: dish?.["quantity"], source: dish?.["quantitySource"] },
          ingredients: await currentIngredientNamesOfDish(),
        }).toEqual({
          dish: { quantity: 2, source: "corrected" },
          ingredients: ["ご飯 200", "鶏もも肉 80"],
        });
      });
    });

    describe("名前をまた直したとき", () => {
      beforeEach(async () => {
        await rename("かつ丼");
        reply();
        await alarm;
      });

      test("始まっていた推定は終えるが当てず、前の材料のままで、状態は推定中のままにすること", async () => {
        expect({
          completions: (await readRows(accountId, "SELECT result FROM estimation_completions"))
            .length,
          ingredients: await currentIngredientNamesOfDish(),
          status: (await pullDishChanges()).findLast(
            ({ kind }) => kind === "dish_estimation_status",
          )?.["status"],
        }).toEqual({
          // 写真の推定と、捨てた推定し直し
          completions: 2,
          ingredients: ["ご飯 200", "鶏もも肉 80"],
          status: "estimating",
        });
      });

      describe("最後の名前の推定し直しが済んだとき", () => {
        beforeEach(async () => {
          await runEstimationAlarm(accountId);
        });

        test("最後の名前で推定し、それだけを当てること", async () => {
          const changes = await pullDishChanges();
          expect({
            lastTarget: readIdentifyDishesRequests(provider).at(-1)?.target,
            version: changes.findLast(({ kind }) => kind === "dish")?.["version"],
            status: changes.findLast(({ kind }) => kind === "dish_estimation_status")?.["status"],
          }).toEqual({
            lastTarget: { type: "dish", dish: expect.objectContaining({ name: "かつ丼" }) },
            // 1 ＋ 名前の修正 2 ＋ 当てた推定し直し 1
            version: 4,
            status: "estimated",
          });
        });
      });
    });

    describe("料理を消したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(dishId)] });
        reply();
        await alarm;
      });

      test("試みの結果だけを書き、届いた推定を捨てること", async () => {
        expect({
          results: (await readRows(accountId, "SELECT result FROM estimation_attempt_results"))
            .length,
          completions: (await readRows(accountId, "SELECT result FROM estimation_completions"))
            .length,
          applications: await readRows(
            accountId,
            `SELECT estimation_id FROM dish_estimation_applications WHERE dish_id = '${dishId}'`,
          ),
        }).toEqual({ results: 2, completions: 1, applications: [] });
      });

      test("推定の行を残し、回数を戻さないこと", async () => {
        expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(2);
      });
    });
  });

  describe("まだ始まっていないうちに名前をもう一度直したとき", () => {
    let secondWriteId: string;
    beforeEach(async () => {
      await rename("カツ丼");
      const second = updateDishWrite(dishId, { name: "かつ丼" });
      secondWriteId = second.id;
      await pushSyncWrites(sessionToken, { writes: [second] });
      await runEstimationAlarm(accountId);
    });

    test("前の予定を、あとの書き込みの控えで取り消し、推定を始めずに数えないこと", async () => {
      expect({
        schedules: (await readDishSchedules()).map(({ cancelled, started }) => ({
          cancelled,
          started,
        })),
        cancellations: await readRows(
          accountId,
          "SELECT sync_write_receipt_id FROM estimation_schedule_cancellations",
        ),
        estimations: (await readRows(accountId, "SELECT id FROM estimations")).length,
      }).toEqual({
        schedules: [
          { cancelled: 1, started: 0 },
          { cancelled: 0, started: 1 },
        ],
        cancellations: [{ sync_write_receipt_id: secondWriteId }],
        estimations: 2,
      });
    });

    test("最後の名前だけで推定すること", () => {
      expect(
        readIdentifyDishesRequests(provider)
          .slice(1)
          .map(({ target }) => target),
      ).toEqual([{ type: "dish", dish: expect.objectContaining({ name: "かつ丼" }) }]);
    });
  });

  describe("提供元が、その名前の料理の材料を出せないと答えたとき", () => {
    beforeEach(async () => {
      mockCreateEstimationProviderOk({ identifiedDishes: { dishes: [] } });
      await rename("謎の料理");
      await runEstimationAlarm(accountId);
    });

    test("通らなかったとして当て、名前と前の量を残し、材料を持たず、料理なしの状態にすること", async () => {
      const changes = await pullDishChanges();
      const dish = changes.findLast(({ kind }) => kind === "dish");
      expect({
        dish: { name: dish?.["name"], quantity: dish?.["quantity"], version: dish?.["version"] },
        ingredientKinds: changes
          .filter(({ kind }) => String(kind).startsWith("ingredient"))
          .map(({ kind }) => kind),
        ingredients: await currentIngredientNamesOfDish(),
        status: changes.at(-1)?.["status"],
      }).toEqual({
        dish: { name: "謎の料理", quantity: 1, version: 3 },
        ingredientKinds: ["ingredient_deletion", "ingredient_deletion"],
        ingredients: [],
        status: "no_dishes",
      });
    });
  });

  describe("提供元が 400 で答えたとき", () => {
    beforeEach(async () => {
      mockCreateEstimationProviderError(
        new EstimationProviderBadRequestError({ errorType: "invalid_request_error" }),
      );
      await rename("カツ丼");
      await runEstimationAlarm(accountId);
    });

    test("通らなかったとして当て、名前と前の量を残し、材料を持たず、推定できなかったの状態にすること", async () => {
      const changes = await pullDishChanges();
      const dish = changes.findLast(({ kind }) => kind === "dish");
      expect({
        dish: { name: dish?.["name"], quantity: dish?.["quantity"] },
        ingredients: await currentIngredientNamesOfDish(),
        status: changes.at(-1)?.["status"],
      }).toEqual({
        dish: { name: "カツ丼", quantity: 1 },
        ingredients: [],
        status: "failed",
      });
    });
  });

  describe("その日の推定の回数を使い切っているとき", () => {
    let countedOn: string;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      await rename("カツ丼");
      const [schedule] = await readDishSchedules();
      const scheduledCountedOn = schedule?.["counted_on"];
      if (typeof scheduledCountedOn !== "string") {
        throw new Error("推定し直しの予定が無い");
      }
      countedOn = scheduledCountedOn;
      await insertCountedEstimations(accountId, countedOn, 29);
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("推定を始めずに見送り、翌日に推定の状態にすること", async () => {
      expect({
        status: (await pullDishChanges()).at(-1)?.["status"],
        estimationsOfDay: (
          await readRows(
            accountId,
            `SELECT e.id FROM estimations e JOIN estimation_schedules s ON s.id = e.estimation_schedule_id WHERE s.counted_on = '${countedOn}'`,
          )
        ).length,
      }).toEqual({ status: "deferred_to_next_day", estimationsOfDay: 30 });
    });

    test("次の日の 0:00 の予定を、同じ料理に、次の日の分として足すこと", async () => {
      expect((await readDishSchedules()).at(-1)).toEqual({
        due_at: Date.parse(`${nextDayOf(countedOn)}T00:00:00+09:00`),
        counted_on: nextDayOf(countedOn),
        cancelled: 0,
        started: 0,
      });
    });

    test("推定を翌日に回した出来事に数えること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "estimation_deferred",
        ),
      ).toHaveLength(1);
    });

    describe("次の日の 0:00 を過ぎてアラームが動いたとき", () => {
      let sequenceBefore: number;
      beforeEach(async () => {
        mockCreateEstimationProviderOk({ replyAfter: new Promise(() => undefined) });
        sequenceBefore = requireLastSequence(await pullChangesAfter(0));
        clock.advance(Date.parse(`${nextDayOf(countedOn)}T00:00:00+09:00`) - Date.now() + 60_000);
        void runDurableObjectAlarm(getAccountDurableObject(env, accountId));
        await waitForEstimationAttempts(accountId, 2);
      });

      test("推定を始め、推定中の状態を届けること", async () => {
        expect(
          (await pullChangesAfter(sequenceBefore)).map(({ kind, record }) => ({
            kind,
            status: record["status"],
          })),
        ).toEqual([{ kind: "dish_estimation_status", status: "estimating" }]);
      });
    });

    describe("見送ったあとに名前を直したとき", () => {
      beforeEach(async () => {
        await rename("かつ丼");
      });

      test("見送った予定が残っても、推定中の状態にし、次の日の予定を取り消すこと", async () => {
        expect({
          status: (await pullDishChanges()).at(-1)?.["status"],
          schedules: (await readDishSchedules()).map(({ cancelled }) => cancelled),
        }).toEqual({
          status: "estimating",
          // 見送った予定、名前を直した予定、取り消した次の日の予定（due_at の順）
          schedules: [0, 0, 1],
        });
      });
    });
  });

  describe("本番のサーバーで", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      captureSpy = mockPostHogCaptureEndpointOk();
    });

    describe("名前を直して推定し直したとき", () => {
      beforeEach(async () => {
        await rename("カツ丼");
        clock.advance(20_000);
        await runEstimationAlarm(accountId);
      });

      test("推定ごとの出来事を、きっかけを「名前を直した」、最後の状態を料理ごとの推定の状態の値で送ること", () => {
        expect(
          readPostHogCapturedEvents(captureSpy).filter(({ event }) => event === "estimation_ended"),
        ).toEqual([
          {
            event: "estimation_ended",
            distinct_id: accountId,
            properties: {
              trigger: "dish_renamed",
              final_status: "estimated",
              retry_count: 0,
              dish_count: 1,
              ingredient_count: 2,
              nutrition_label_ingredient_count: 0,
              food_composition_ingredient_count: 1,
              estimated_ingredient_count: 1,
              seconds_from_received_to_ended: 20,
              provider_error_types: [],
              $geoip_disable: true,
            },
          },
        ]);
      });

      describe("そのあとに料理を直したとき", () => {
        beforeEach(async () => {
          captureSpy.mockClear();
          // rename も 1 秒進めるので、合わせて 90 秒
          clock.advance(89_000);
          await rename("かつ丼");
        });

        test("推定し直しを当てたあとに直したことと、当てた推定の終わりからの経過時間を送ること", () => {
          expect(
            readPostHogCapturedEvents(captureSpy).filter(
              ({ event }) => event === "reestimated_dish_edited",
            ),
          ).toEqual([
            {
              event: "reestimated_dish_edited",
              distinct_id: accountId,
              properties: {
                action: "corrected",
                seconds_from_reestimation_ended: 90,
                $geoip_disable: true,
              },
            },
          ]);
        });
      });

      describe("そのあとに料理を消したとき", () => {
        beforeEach(async () => {
          captureSpy.mockClear();
          clock.advance(45_000);
          await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(dishId)] });
        });

        test("推定し直しを当てたあとに消したことと、当てた推定の終わりからの経過時間を送ること", () => {
          expect(
            readPostHogCapturedEvents(captureSpy).map(({ event, properties }) => ({
              event,
              properties,
            })),
          ).toEqual([
            {
              event: "reestimated_dish_edited",
              properties: {
                action: "deleted",
                seconds_from_reestimation_ended: 45,
                $geoip_disable: true,
              },
            },
          ]);
        });
      });

      describe("そのあとに前の材料の量を直す書き込みを送ったとき", () => {
        beforeEach(async () => {
          captureSpy.mockClear();
          await pushSyncWrites(sessionToken, { writes: [updateIngredientWrite(riceId, 150)] });
        });

        test("受け付けなかった書き込みを、材料の種類と、材料が置き換わった理由で送ること", () => {
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
                record_type: "ingredient",
                reason: "ingredients_replaced",
                $geoip_disable: true,
              },
            },
          ]);
        });
      });
    });

    describe("料理を足して推定し直したとき", () => {
      let addedDishId: string;
      beforeEach(async () => {
        clock.advance(1000);
        const write = createDishWrite(mealId, { name: "味噌汁" });
        addedDishId = write.dishId;
        await pushSyncWrites(sessionToken, { writes: [write] });
        clock.advance(20_000);
        await runEstimationAlarm(accountId);
      });

      test("推定ごとの出来事を、きっかけを「料理を足した」で送ること", () => {
        expect(readEndedTriggers(captureSpy)).toEqual(["dish_added"]);
      });

      describe("そのあとに足した料理の名前を直して推定し直したとき", () => {
        beforeEach(async () => {
          captureSpy.mockClear();
          clock.advance(1000);
          await pushSyncWrites(sessionToken, {
            writes: [updateDishWrite(addedDishId, { name: "豚汁" })],
          });
          clock.advance(1000);
          await runEstimationAlarm(accountId);
        });

        test("推定ごとの出来事を、きっかけを「名前を直した」で送ること", () => {
          expect(readEndedTriggers(captureSpy)).toEqual(["dish_renamed"]);
        });
      });
    });

    describe("推定し直しの呼び出し中に料理を消したとき", () => {
      beforeEach(async () => {
        const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
        mockCreateEstimationProviderOk({ replyAfter });
        await rename("カツ丼");
        const alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
        await waitForEstimationAttempts(accountId, 2);
        captureSpy.mockClear();
        await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(dishId)] });
        reply();
        await alarm;
      });

      test("推定ごとの出来事を「料理が消えた」で送ること", () => {
        expect(
          readPostHogCapturedEvents(captureSpy)
            .filter(({ event }) => event === "estimation_ended")
            .map(({ properties }) => ({
              trigger: properties["trigger"],
              finalStatus: properties["final_status"],
            })),
        ).toEqual([{ trigger: "dish_renamed", finalStatus: "dish_deleted" }]);
      });
    });

    describe("名前をまた直して推定し直しの呼び出しが2つ並んでいるあいだに料理を消したとき", () => {
      beforeEach(async () => {
        const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
        mockCreateEstimationProviderOk({ replyAfter });
        await rename("カツ丼");
        const first = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
        await waitForEstimationAttempts(accountId, 2);
        await rename("かつ丼");
        const second = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
        await waitForEstimationAttempts(accountId, 3);
        captureSpy.mockClear();
        await pushSyncWrites(sessionToken, { writes: [deleteDishWrite(dishId)] });
        reply();
        await Promise.all([first, second]);
      });

      test("呼び出し中の推定のそれぞれについて、推定ごとの出来事を「料理が消えた」で送ること", () => {
        expect(
          readPostHogCapturedEvents(captureSpy)
            .filter(({ event }) => event === "estimation_ended")
            .map(({ properties }) => properties["final_status"]),
        ).toEqual(["dish_deleted", "dish_deleted"]);
      });
    });
  });
});

const readEndedTriggers = (captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>) =>
  readPostHogCapturedEvents(captureSpy)
    .filter(({ event }) => event === "estimation_ended")
    .map(({ properties }) => properties["trigger"]);

const nextDayOf = (day: string) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);
