import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import type { EstimationWrites } from "../domain/estimation-writes";

const meal1 = generateRecordId();
const meal2 = generateRecordId();

// 推定の書き込みの口（ドメイン層の writeEstimationEvents）を、Durable Object の置き場で組んだ形で確かめる。
// ドメイン層のテストは cloudflare:test を import できないので、ここに置く
type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;
type Run = (writes: EstimationWrites) => void;

// 書く前の予定と結果を seed で作り、run で書いて、足された推定の状態の変更を返す
const writeInAccount = (seed: Seed, run: Run): Promise<RecordChangeTarget<string>[]> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    const changes: RecordChangeTarget<string>[] = [];
    createRecordKindStores(state.storage).writeEstimationEvents(
      (change) => {
        changes.push(change);
      },
      new Date(),
      run,
    );
    return changes;
  });

// 待っている予定のある食事。見送り・開始の前の形
const seedWaitingSchedule = async (
  factory: ReturnType<typeof durableObjectFactory>,
  ids: { mealId: RecordId; scheduleId: string },
) => {
  await factory.meals.create({ id: ids.mealId });
  await factory.estimationSchedules.create({ id: ids.scheduleId });
  await factory.mealEstimationSchedules.create({
    estimationScheduleId: ids.scheduleId,
    mealId: ids.mealId,
  });
};

// 見送った予定と、次の日の待っている予定のある食事
const seedDeferredSchedule = async (factory: ReturnType<typeof durableObjectFactory>) => {
  await factory.meals.create({ id: meal1 });
  await factory.estimationSchedules.create({ id: "schedule-1", dueAt: startedAt });
  await factory.mealEstimationSchedules.create({
    estimationScheduleId: "schedule-1",
    mealId: meal1,
  });
  await factory.estimationDeferrals.create({ estimationScheduleId: "schedule-1" });
  await factory.estimationSchedules.create({
    id: "schedule-2",
    dueAt: nextDayStartsAt,
    countedOn: "2026-01-02",
  });
  await factory.mealEstimationSchedules.create({
    estimationScheduleId: "schedule-2",
    mealId: meal1,
  });
};

// 推定を始めた予定のある食事
const seedStartedEstimation = async (factory: ReturnType<typeof durableObjectFactory>) => {
  await seedWaitingSchedule(factory, { mealId: meal1, scheduleId: "schedule-1" });
  await factory.estimations.create({ id: "estimation-1", estimationScheduleId: "schedule-1" });
};

const startedAt = new Date("2026-01-01T00:00:00Z");
const nextDayStartsAt = new Date("2026-01-01T15:00:00Z");

describe("推定の書き込みの口", () => {
  describe("予定が無い食事に予定を入れるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = async (factory) => {
        await factory.meals.create({ id: meal1 });
      };
      run = (writes) => {
        writes.scheduleMeal({
          id: "schedule-1",
          mealId: meal1,
          dueAt: startedAt,
          countedOn: "2026-01-01",
        });
      };
    });

    test("推定の状態の変更を足すこと（推定待ち → 推定中）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("待っている予定を翌日に見送るとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = (factory) => seedWaitingSchedule(factory, { mealId: meal1, scheduleId: "schedule-1" });
      run = (writes) => {
        writes.deferToNextDay({
          scheduleId: "schedule-1",
          target: { type: "meal", mealId: meal1 },
          deferredAt: startedAt,
          nextSchedule: { id: "schedule-2", dueAt: nextDayStartsAt, countedOn: "2026-01-02" },
        });
      };
    });

    test("推定の状態の変更を足すこと（推定中 → 翌日に推定）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("見送ったあとの予定から推定を始めるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = seedDeferredSchedule;
      run = (writes) => {
        writes.beginEstimation({
          id: "estimation-1",
          scheduleId: "schedule-2",
          target: { type: "meal", mealId: meal1 },
          startedAt: nextDayStartsAt,
        });
      };
    });

    test("推定の状態の変更を足すこと（翌日に推定 → 推定中）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("見送っていない予定から推定を始めるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = (factory) => seedWaitingSchedule(factory, { mealId: meal1, scheduleId: "schedule-1" });
      run = (writes) => {
        writes.beginEstimation({
          id: "estimation-1",
          scheduleId: "schedule-1",
          target: { type: "meal", mealId: meal1 },
          startedAt,
        });
        writes.beginAttempt({
          id: "attempt-1",
          estimationId: "estimation-1",
          attemptedAt: startedAt,
        });
      };
    });

    test("推定の状態の変更を足さないこと（推定中のまま）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([]);
    });
  });

  describe("推定を推定済みで終えるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = seedStartedEstimation;
      run = (writes) => {
        writes.complete({
          estimationId: "estimation-1",
          target: { type: "meal", mealId: meal1 },
          completedAt: startedAt,
          result: "estimated",
        });
      };
    });

    test("推定の状態の変更を足すこと（推定中 → 推定済み）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("推定を料理なしで終えるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = seedStartedEstimation;
      run = (writes) => {
        writes.complete({
          estimationId: "estimation-1",
          target: { type: "meal", mealId: meal1 },
          completedAt: startedAt,
          result: "no_dishes",
        });
      };
    });

    test("推定の状態の変更を足すこと（推定中 → 料理なし）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("推定をあきらめるとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = seedStartedEstimation;
      run = (writes) => {
        writes.abandon({
          estimationId: "estimation-1",
          target: { type: "meal", mealId: meal1 },
          abandonedAt: startedAt,
        });
      };
    });

    test("推定の状態の変更を足すこと（推定中 → 推定できなかった）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
      ]);
    });
  });

  describe("1つの関数で、状態の変わらない食事と変わる食事に書くとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = async (factory) => {
        await seedWaitingSchedule(factory, { mealId: meal1, scheduleId: "schedule-1" });
        await seedWaitingSchedule(factory, { mealId: meal2, scheduleId: "schedule-2" });
      };
      run = (writes) => {
        writes.beginEstimation({
          id: "estimation-1",
          scheduleId: "schedule-1",
          target: { type: "meal", mealId: meal1 },
          startedAt,
        });
        writes.deferToNextDay({
          scheduleId: "schedule-2",
          target: { type: "meal", mealId: meal2 },
          deferredAt: startedAt,
          nextSchedule: { id: "schedule-3", dueAt: nextDayStartsAt, countedOn: "2026-01-02" },
        });
      };
    });

    test("状態の変わった食事の分だけ、推定の状態の変更を足すこと", async () => {
      expect(await writeInAccount(seed, run)).toEqual([
        { recordType: "meal_estimation_status", recordId: meal2 },
      ]);
    });
  });

  describe("1つの関数で同じ食事に2回書いて、元の状態に戻るとき", () => {
    let seed: Seed;
    let run: Run;
    beforeEach(() => {
      seed = (factory) => seedWaitingSchedule(factory, { mealId: meal1, scheduleId: "schedule-1" });
      run = (writes) => {
        writes.deferToNextDay({
          scheduleId: "schedule-1",
          target: { type: "meal", mealId: meal1 },
          deferredAt: startedAt,
          nextSchedule: { id: "schedule-2", dueAt: nextDayStartsAt, countedOn: "2026-01-02" },
        });
        writes.beginEstimation({
          id: "estimation-1",
          scheduleId: "schedule-2",
          target: { type: "meal", mealId: meal1 },
          startedAt: nextDayStartsAt,
        });
      };
    });

    test("推定の状態の変更を足さないこと（推定中 → 翌日に推定 → 推定中）", async () => {
      expect(await writeInAccount(seed, run)).toEqual([]);
    });
  });

  describe("文章の食事の推定", () => {
    const sentText = generateRecordId();
    const createdEatenAt = new Date("2026-01-01T00:00:00Z");
    const estimatedEatenAt = new Date("2025-12-31T10:00:00Z");

    // 同じ送った文章の文章の食事が2つあり、1つ目（meal1）だけが予定のつなぎを持って推定中
    const seedWrittenMeals: Seed = async (factory) => {
      await factory.sentTexts.create({ id: sentText });
      for (const mealId of [meal1, meal2]) {
        await factory.meals.create({ id: mealId, eatenAt: createdEatenAt, entryMethod: "written" });
        await factory.sentTextMeals.create({ mealId, sentTextId: sentText });
      }
      await factory.estimationSchedules.create({ id: "schedule-1" });
      await factory.mealEstimationSchedules.create({
        estimationScheduleId: "schedule-1",
        mealId: meal1,
      });
      await factory.estimations.create({ id: "estimation-1", estimationScheduleId: "schedule-1" });
    };

    // 書いたあとの食事の今の時刻
    const writeAndReadEatenAts = (seed: Seed, run: Run) =>
      runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
        await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
        const stores = createRecordKindStores(state.storage);
        stores.writeEstimationEvents(() => undefined, new Date(), run);
        return [meal1, meal2].map((mealId) => stores.meal.find(mealId)?.eatenAt);
      });

    test("時刻を決めるのは、推定の予定のつなぎの食事だけであること", async () => {
      expect(
        await writeAndReadEatenAts(seedWrittenMeals, (writes) => {
          writes.estimateMealEatenAt({ estimationId: "estimation-1", eatenAt: estimatedEatenAt });
        }),
      ).toEqual([estimatedEatenAt, createdEatenAt]);
    });

    test("1つの推定が同じ食事の時刻を二度は決めないこと", async () => {
      await expect(
        writeAndReadEatenAts(seedWrittenMeals, (writes) => {
          writes.estimateMealEatenAt({ estimationId: "estimation-1", eatenAt: estimatedEatenAt });
          writes.estimateMealEatenAt({ estimationId: "estimation-1", eatenAt: createdEatenAt });
        }),
      ).rejects.toThrow(/UNIQUE constraint failed: meal_eaten_at_estimations/);
    });

    test("食事の予定のつなぎが無い推定は、時刻を決められないこと", async () => {
      await expect(
        writeAndReadEatenAts(
          async (factory) => {
            await seedWrittenMeals(factory);
            await factory.estimations.create({ id: "estimation-2" });
          },
          (writes) => {
            writes.estimateMealEatenAt({ estimationId: "estimation-2", eatenAt: estimatedEatenAt });
          },
        ),
      ).rejects.toThrow(/食事の予定から始まった推定でない/);
    });

    test("推定を完了して2つめ以降の食事を作ると、どちらの食事にも推定の状態の変更を足すこと", async () => {
      expect(
        await writeInAccount(seedWrittenMeals, (writes) => {
          writes.complete({
            estimationId: "estimation-1",
            target: { type: "meal", mealId: meal1 },
            completedAt: startedAt,
            result: "estimated",
          });
          writes.recordCreatedMeal({ mealId: meal2, estimationId: "estimation-1" });
        }),
      ).toEqual([
        { recordType: "meal_estimation_status", recordId: meal1 },
        { recordType: "meal_estimation_status", recordId: meal2 },
      ]);
    });
  });
});
