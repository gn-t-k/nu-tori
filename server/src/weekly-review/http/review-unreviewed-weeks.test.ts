import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { computeStartOfWeek } from "../../domain/compute-start-of-week";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { postGoalSetup } from "../../http/goal-setup-routes/testing/post-goal-setup";
import { recordDailyWeights } from "../../http/goal-setup-routes/testing/record-daily-weights";
import { putMealPhoto } from "../../http/meal-photo-routes/testing/put-meal-photo";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";

const millisecondsPerDay = 86_400_000;

// 起こす要求と起こさない要求、要求の中の順を受け口から確かめる。書いた行を見分けやすいよう、どの場面も見送る週にする。
// 見直せる週を書くことは write-reviewed-weeks.test.ts で確かめる
describe("まだ見直していない週を見る要求", () => {
  let accountId: string;
  let sessionToken: string;
  let goalId: RecordId;
  // 目標の開始の日のあとの最初の月曜
  let firstMonday: string;
  let readReviews: () => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    // 時計をサインインの1日あとで止め、その日に目標を立てたことにする
    useFakeClock(Date.now() + millisecondsPerDay);
    const goalStartedOn = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    firstMonday = addDays(computeStartOfWeek(goalStartedOn), 7);
    // 体重は、最初の月曜の入力の週より前の 14 日だけ。入力の週には体重記録が無い
    await recordDailyWeights(
      sessionToken,
      Array.from({ length: 14 }, (_, offset) => addDays(firstMonday, offset - 21)),
      70,
    );
    goalId = generateRecordId();
    // 推定の始まりは逆算にし、使い始めて7日未満を当てない
    await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
      const factory = durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }));
      await factory.goals.create({ id: goalId, startedOn: goalStartedOn });
      const estimate = await factory.expenditureEstimates.create({
        effectiveOn: goalStartedOn,
        expenditureKcal: 2400,
      });
      await factory.initialExpenditureEstimates.create({
        expenditureEstimateId: estimate.id,
        source: "back_calculated",
      });
    });
    // 最初の月曜の日本時間 9 時
    vi.setSystemTime(Date.parse(`${firstMonday}T00:00:00Z`));
    readReviews = () =>
      readRows(
        accountId,
        "SELECT w.effective_on, w.reviewed_at, w.time_zone, d.goal_id, d.reason FROM weekly_reviews w JOIN deferred_weekly_reviews d ON d.weekly_review_id = w.id ORDER BY w.effective_on",
      );
  });

  describe("月曜 0:00 を過ぎた最初の要求が、送り切った印のある送る要求のとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, { writes: [], isFinalBatch: true });
    });

    test("その月曜の週を、要求のタイムゾーンで、今の目標に体重が無いとして見送ること", async () => {
      expect(await readReviews()).toEqual([
        {
          effective_on: firstMonday,
          reviewed_at: Date.now(),
          time_zone: "Asia/Tokyo",
          goal_id: goalId,
          reason: "no_weight",
        },
      ]);
    });
  });

  describe("その要求で、入力の週の日曜の体重記録を送り切ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [
          createWeightRecordWrite({
            weightRecord: {
              weightKg: 70,
              measuredAt: Date.parse(`${addDays(firstMonday, -1)}T00:00:00Z`),
              timeZone: "Asia/Tokyo",
            },
          }),
        ],
        isFinalBatch: true,
      });
    });

    test("送った体重を当ててから見て、体重が無いでなく食事の記録が少ないで見送ること", async () => {
      expect((await readReviews()).map(({ reason }) => reason)).toEqual(["few_meal_records"]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、送り切っていない送る要求のとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, { writes: [], isFinalBatch: false });
    });

    test("見直さないこと", async () => {
      expect(await readReviews()).toEqual([]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、写真の要求のとき", () => {
    beforeEach(async () => {
      const photoId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { photos: [{ id: photoId }] } })],
        isFinalBatch: false,
      });
      await putMealPhoto(sessionToken, photoId);
    });

    test("見直さないこと", async () => {
      expect(await readReviews()).toEqual([]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、取りに行く要求のとき", () => {
    let pulled: PullResult;
    beforeEach(async () => {
      pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    test("見送った週の見直しが、その応答の変更で届くこと", () => {
      const review = pulled.changes.find(({ kind }) => kind === "weekly_review");
      expect(pulled.changes.filter(({ kind }) => kind === "weekly_review")).toEqual([
        {
          sequence: review?.sequence,
          kind: "weekly_review",
          recordId: review?.recordId,
          record: {
            id: review?.recordId,
            effectiveOn: firstMonday,
            reviewedAt: Date.now(),
            timeZone: "Asia/Tokyo",
            deferral: { reason: "no_weight", goalId },
          },
        },
      ]);
    });

    describe("同じ週のうちに、もう一度取りに行ったとき", () => {
      beforeEach(async () => {
        vi.setSystemTime(Date.now() + millisecondsPerDay);
        await pullSyncChanges(sessionToken);
      });

      test("同じ週を2回見直さないこと", async () => {
        expect((await readReviews()).map(({ effective_on }) => effective_on)).toEqual([
          firstMonday,
        ]);
      });
    });

    describe("次の月曜 0:00 を過ぎて取りに行ったとき", () => {
      beforeEach(async () => {
        vi.setSystemTime(Date.now() + 7 * millisecondsPerDay);
        await pullSyncChanges(sessionToken);
      });

      test("次の週だけを見直すこと", async () => {
        expect((await readReviews()).map(({ effective_on }) => effective_on)).toEqual([
          firstMonday,
          addDays(firstMonday, 7),
        ]);
      });
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、目標の下見の要求のとき", () => {
    beforeEach(async () => {
      await postGoalSetup(sessionToken, "preview", { direction: "maintain" });
    });

    test("その月曜の週を見送ること", async () => {
      expect((await readReviews()).map(({ effective_on }) => effective_on)).toEqual([firstMonday]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、目標案の要求のとき", () => {
    beforeEach(async () => {
      await postGoalSetup(sessionToken, "proposals", { plan: { direction: "maintain" } });
    });

    test("その月曜の週を見送ること", async () => {
      expect((await readReviews()).map(({ effective_on }) => effective_on)).toEqual([firstMonday]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、自分で決める目標体重の要求のとき", () => {
    beforeEach(async () => {
      await postGoalSetup(sessionToken, "custom-target-weight", {
        direction: "lose",
        deadlineOn: addDays(firstMonday, 90),
        targetWeightKg: 67,
      });
    });

    test("その月曜の週を見送ること", async () => {
      expect((await readReviews()).map(({ effective_on }) => effective_on)).toEqual([firstMonday]);
    });
  });

  describe("月曜 0:00 を過ぎた最初の要求が、その月曜から維持の目標に立て直す要求のとき", () => {
    let decision: { status: string };
    beforeEach(async () => {
      decision = await (
        await postGoalSetup(sessionToken, "decisions", {
          requestId: generateRecordId(),
          startedOn: firstMonday,
          choice: { type: "maintain" },
          shown: {
            targetWeightKg: 70,
            dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
          },
          rejectedCustomTargetWeightCount: 0,
        })
      ).json();
    });

    test("目標を決めるより先に見直し、見送りが前の目標を指すこと", async () => {
      expect({
        status: decision.status,
        reviews: (await readReviews()).map(({ effective_on, goal_id }) => ({
          effective_on,
          goal_id,
        })),
      }).toEqual({
        status: "decided",
        reviews: [{ effective_on: firstMonday, goal_id: goalId }],
      });
    });
  });

  describe("最初の月曜から2週あとの水曜に、初めて取りに行ったとき", () => {
    let pulled: PullResult;
    beforeEach(async () => {
      vi.setSystemTime(Date.now() + 16 * millisecondsPerDay);
      pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    test("古い順に1週ずつ見送り、見直した時刻がそろうこと", async () => {
      expect(await readReviews()).toEqual(
        [0, 7, 14].map((offset) => ({
          effective_on: addDays(firstMonday, offset),
          reviewed_at: Date.now(),
          time_zone: "Asia/Tokyo",
          goal_id: goalId,
          reason: "no_weight",
        })),
      );
    });

    test("週の見直しの変更が、古い週から順に並ぶこと", () => {
      expect(
        pulled.changes
          .filter(({ kind }) => kind === "weekly_review")
          .map(({ record }) => record["effectiveOn"]),
      ).toEqual([0, 7, 14].map((offset) => addDays(firstMonday, offset)));
    });
  });

  describe("要求ごとのログ", () => {
    let logSpy: ReturnType<typeof vi.spyOn>;
    // 受け口の要求ごとのログのうち、その経路のものの、見直した週の数
    const readReviewedWeekCounts = (route: string): unknown[] =>
      logSpy.mock.calls.flatMap(([entry]: unknown[]) =>
        typeof entry === "object" && entry !== null && Reflect.get(entry, "route") === route
          ? [Reflect.get(entry, "reviewedWeekCount")]
          : [],
      );
    beforeEach(() => {
      logSpy = vi.spyOn(console, "log");
    });

    describe("最初の月曜から2週あとに取りに行き、もう一度取りに行ったとき", () => {
      beforeEach(async () => {
        vi.setSystemTime(Date.now() + 14 * millisecondsPerDay);
        await pullSyncChanges(sessionToken);
        await pullSyncChanges(sessionToken);
      });

      test("見直した週の数を、要求ごとに出すこと", () => {
        expect(readReviewedWeekCounts("GET /v1/sync/changes")).toEqual([3, 0]);
      });
    });

    describe("月曜 0:00 を過ぎた最初の要求が、目標の下見の要求のとき", () => {
      beforeEach(async () => {
        await postGoalSetup(sessionToken, "preview", { direction: "maintain" });
      });

      test("見直した週の数を出すこと", () => {
        expect(readReviewedWeekCounts("POST /v1/goal-setup/preview")).toEqual([1]);
      });
    });

    describe("見直しが失敗したとき", () => {
      let response: Response;
      beforeEach(async () => {
        // 今の目標が無い、書く口が作らない状態にして、見直しを失敗させる
        await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
          const factory = durableObjectFactory(
            drizzle(state.storage, { schema: durableObjectTables }),
          );
          await factory.goalClosures.create({ goalId, nextGoalId: goalId });
        });
        response = await pullSyncChanges(sessionToken);
      });

      test("要求の失敗にし、例外の名前をログに出すこと", () => {
        expect({
          status: response.status,
          logged: logSpy.mock.calls.flatMap(([entry]: unknown[]) =>
            typeof entry === "object" &&
            entry !== null &&
            Reflect.get(entry, "route") === "GET /v1/sync/changes"
              ? [{ status: Reflect.get(entry, "status"), error: Reflect.get(entry, "error") }]
              : [],
          ),
        }).toEqual({ status: 500, logged: [{ status: 500, error: "Error" }] });
      });
    });

    describe("送り切っていない送る要求のとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [], isFinalBatch: false });
      });

      test("見直さないので、見直した週の数を出さないこと", () => {
        expect(readReviewedWeekCounts("POST /v1/sync/writes")).toEqual([undefined]);
      });
    });
  });
});
