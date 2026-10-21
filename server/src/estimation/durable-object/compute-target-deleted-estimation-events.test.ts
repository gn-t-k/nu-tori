import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import type { UsageEvent } from "../../domain/usage-event";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { computeTargetDeletedEstimationEvents } from "../domain/compute-target-deleted-estimation-events";

// 対象が消えるときの推定ごとの出来事（ドメイン層の computeTargetDeletedEstimationEvents）を、Durable Object の置き場で確かめる。
// ドメイン層のテストは cloudflare:test を import できないので、ここに置く
type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;

const mealId = generateRecordId();
const receivedAt = new Date("2026-01-01T00:00:00Z");
const deletedAt = new Date("2026-01-01T00:00:45Z");

// 書く前の予定と推定を seed で作り、食事が消えるときの出来事を返す
const computeInAccount = (seed: Seed): Promise<UsageEvent[]> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    return computeTargetDeletedEstimationEvents(
      createRecordKindStores(state.storage),
      { type: "meal", mealId },
      "meal_deleted",
      deletedAt,
    );
  });

// 推定を始めた予定のある食事
const seedStartedEstimation: Seed = async (factory) => {
  await factory.meals.create({ id: mealId });
  await factory.estimationSchedules.create({ id: "schedule-1", dueAt: receivedAt });
  await factory.mealEstimationSchedules.create({ estimationScheduleId: "schedule-1", mealId });
  await factory.estimations.create({ id: "estimation-1", estimationScheduleId: "schedule-1" });
};

describe("対象が消えるときの推定ごとの出来事", () => {
  describe("推定中の食事が消えるとき", () => {
    let events: UsageEvent[];
    beforeEach(async () => {
      events = await computeInAccount(seedStartedEstimation);
    });

    test("消えたものの区分で、料理と材料を数えずに出来事を返すこと", () => {
      expect(events).toEqual([
        {
          name: "estimation_ended",
          trigger: "photo",
          finalStatus: "meal_deleted",
          retryCount: 0,
          dishCount: 0,
          ingredientCount: 0,
          nutritionLabelIngredientCount: 0,
          foodCompositionIngredientCount: 0,
          estimatedIngredientCount: 0,
          secondsFromReceivedToEnded: 45,
          providerErrorTypes: [],
        },
      ]);
    });
  });

  describe("推定を始めていない食事が消えるとき", () => {
    let events: UsageEvent[];
    beforeEach(async () => {
      events = await computeInAccount(async (factory) => {
        await factory.meals.create({ id: mealId });
        await factory.estimationSchedules.create({ id: "schedule-1", dueAt: receivedAt });
        await factory.mealEstimationSchedules.create({
          estimationScheduleId: "schedule-1",
          mealId,
        });
      });
    });

    test("出来事を返さないこと", () => {
      expect(events).toEqual([]);
    });
  });
});
