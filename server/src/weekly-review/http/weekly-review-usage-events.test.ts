import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { updateAccountSettingsWrite } from "../../account-settings/http/testing/update-account-settings-write";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { computeStartOfWeek } from "../../domain/compute-start-of-week";
import { generateRecordId } from "../../domain/record-id";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { recordDailyWeights } from "../../http/goal-setup-routes/testing/record-daily-weights";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { recordMealEnergies } from "./testing/record-meal-energies";

const millisecondsPerDay = 86_400_000;

const daysFrom = (from: string, count: number): string[] =>
  Array.from({ length: count }, (_, offset) => addDays(from, offset));

// 週の見直しで PostHog に送る出来事を、受け口から確かめる。
// 維持の目標（70 kg）に、逆算した推定 2,400 kcal と1日の目安 2,400 kcal が当たっている。
// 最初の月曜の入力の週は、毎日 70 kg で、食事を7日とも 2,200 kcal 記録したので、新しい推定は 2,350 kcal になる。
// そのあとの週は体重も食事も記録しない
describe("週の見直しの出来事", () => {
  let accountId: string;
  let sessionToken: string;
  // 目標の開始の日のあとの最初の月曜
  let firstMonday: string;
  let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
  const readWeeklyReviewEvents = () =>
    readPostHogCapturedEvents(fetchSpy).filter(({ event }) => event === "weekly_review");
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    useFakeClock(Date.now() + millisecondsPerDay);
    const goalStartedOn = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    firstMonday = addDays(computeStartOfWeek(goalStartedOn), 7);
    await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
      const factory = durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }));
      const goal = await factory.goals.create({
        startedOn: goalStartedOn,
        startingWeightTrendKg: 70,
        targetWeightKg: 70,
      });
      const estimate = await factory.expenditureEstimates.create({
        effectiveOn: goalStartedOn,
        expenditureKcal: 2400,
      });
      // 推定の始まりは逆算にし、使い始めて7日未満を当てない
      await factory.initialExpenditureEstimates.create({
        expenditureEstimateId: estimate.id,
        source: "back_calculated",
      });
      await factory.dailyGuides.create({
        goalId: goal.id,
        expenditureEstimateId: estimate.id,
        effectiveOn: goalStartedOn,
        energyKcal: 2400,
        proteinG: 110,
        fatG: 65,
        carbohydrateG: 345,
      });
    });
    vi.setSystemTime(Date.parse(`${firstMonday}T00:00:00Z`));
    await recordDailyWeights(sessionToken, daysFrom(addDays(firstMonday, -21), 21), 70);
    await recordMealEnergies(accountId, daysFrom(addDays(firstMonday, -7), 7), 2200);
    await enableUsageEventSending(accountId);
    fetchSpy = mockPostHogCaptureEndpointOk();
  });

  describe("見直せる週の月曜に取りに行ったとき", () => {
    beforeEach(async () => {
      await pullSyncChanges(sessionToken);
    });

    test("見直せたことと、主な理由、当たった上限と下限、推定消費カロリーの差、推定の始まりの出どころを送ること", () => {
      expect(readWeeklyReviewEvents()).toEqual([
        {
          event: "weekly_review",
          distinct_id: accountId,
          properties: {
            deferred: false,
            limit_hits: [],
            main_reason: "expenditure_change",
            expenditure_change_kcal: -50,
            initial_expenditure_source: "back_calculated",
            reviewed_week_count: 1,
            $geoip_disable: true,
          },
        },
      ]);
    });

    test("体重と kcal の値を含めないこと", () => {
      // 体重（70）、推定（2400・2350）、1日の目安（2400・2350）と P・F・C（110・65・345・330）、食事（2200）
      expect(JSON.stringify(readWeeklyReviewEvents())).not.toMatch(
        /[:,[]"?(?:70|2400|2350|110|65|345|330|2200)"?[,}\]]/u,
      );
    });

    test("同じ週を2回見直さず、2回めの要求では送らないこと", async () => {
      await pullSyncChanges(sessionToken);
      expect(readWeeklyReviewEvents()).toHaveLength(1);
    });
  });

  describe("最初の月曜から 7 週あとに、はじめて取りに行ったとき", () => {
    beforeEach(async () => {
      vi.setSystemTime(Date.parse(`${addDays(firstMonday, 49)}T00:00:00Z`));
      await pullSyncChanges(sessionToken);
    });

    test("8 週を古い順に1つずつ、まとめて見直した週の数とともに送ること", () => {
      expect(
        readWeeklyReviewEvents().map(({ properties }) => ({
          deferred: properties["deferred"],
          deferralReason: properties["deferral_reason"],
          reviewedWeekCount: properties["reviewed_week_count"],
        })),
      ).toEqual([
        { deferred: false, deferralReason: undefined, reviewedWeekCount: 8 },
        ...Array.from({ length: 7 }, () => ({
          deferred: true,
          deferralReason: "no_weight",
          reviewedWeekCount: 8,
        })),
      ]);
    });

    test("推定の始まりから 4 回めと 8 回めの見直しだけ、推定と初期値との差を送ること", () => {
      expect(
        readWeeklyReviewEvents().map(
          ({ properties }) => properties["expenditure_change_from_initial_kcal"],
        ),
      ).toEqual([undefined, undefined, undefined, -50, undefined, undefined, undefined, -50]);
    });
  });

  describe("利用状況を送らない人が、見直せる週の月曜に取りに行ったとき", () => {
    beforeEach(async () => {
      await pushSyncWrites(sessionToken, {
        writes: [updateAccountSettingsWrite({ accountSettings: { sendsUsageData: false } })],
      });
      await pullSyncChanges(sessionToken);
    });

    test("週の見直しの出来事を送らないこと", () => {
      expect(readWeeklyReviewEvents()).toEqual([]);
    });
  });
});
