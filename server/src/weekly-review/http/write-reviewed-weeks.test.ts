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
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { recordMealEnergies } from "./testing/record-meal-energies";
import { millisecondsPerDay } from "../../domain/milliseconds-per-day";
import { daysFrom } from "../testing/days-from";

// 見直せる週を受け口から書く。どの週も、毎日 70 kg で体重が変わらず、食事を7日とも 2,200 kcal 記録した週にする。
// 維持の目標（70 kg）に、推定 2,400 kcal と1日の目安 2,400 kcal が当たっている。
// 最初の週は、予測した変化が（2,200 − 2,400）× 7 ÷ 7,700 = −0.18 kg、実際の変化が 0 kg で、
// 新しい推定は 2,400 − 0.25 × 7,700 × 0.18 ÷ 7 = 2,350 kcal。維持の1日の目安も 2,350 kcal になる
describe("見直せる週を書く要求", () => {
  let accountId: string;
  let sessionToken: string;
  let goalId: RecordId;
  // 目標の開始の日のあとの最初の月曜
  let firstMonday: string;
  let readReviewedEstimates: () => Promise<Record<string, unknown>[]>;
  let readReviewedDailyGuides: () => Promise<Record<string, unknown>[]>;
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
      await factory.dailyGuides.create({
        goalId,
        expenditureEstimateId: estimate.id,
        effectiveOn: goalStartedOn,
        energyKcal: 2400,
        proteinG: 110,
        fatG: 65,
        carbohydrateG: 345,
      });
    });
    readReviewedEstimates = () =>
      readRows(
        accountId,
        "SELECT e.effective_on, e.expenditure_kcal, e.estimated_at, r.deviation_direction, w.reviewed_at FROM reviewed_expenditure_estimates r JOIN expenditure_estimates e ON e.id = r.expenditure_estimate_id JOIN weekly_reviews w ON w.id = r.weekly_review_id ORDER BY e.effective_on",
      );
    readReviewedDailyGuides = () =>
      readRows(
        accountId,
        "SELECT g.goal_id, g.effective_on, g.energy_kcal, g.protein_g, g.fat_g, g.carbohydrate_g, r.main_reason FROM reviewed_daily_guides r JOIN daily_guides g ON g.id = r.daily_guide_id ORDER BY g.effective_on",
      );
  });

  // 最初の月曜の入力の週と、その前の 14 日の体重と、入力の週の食事を置き、時計を最初の月曜の日本時間 9 時にする
  const recordFirstWeek = async () => {
    vi.setSystemTime(Date.parse(`${firstMonday}T00:00:00Z`));
    await recordDailyWeights(sessionToken, daysFrom(addDays(firstMonday, -21), 21), 70);
    await recordMealEnergies(accountId, daysFrom(addDays(firstMonday, -7), 7), 2200);
  };

  describe("見直せる週の月曜 0:00 を過ぎて取りに行ったとき", () => {
    let pulled: PullResult;
    beforeEach(async () => {
      await recordFirstWeek();
      pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    test("その月曜から当てる新しい推定を、見直した時刻とずれの向きとともに書くこと", async () => {
      expect(await readReviewedEstimates()).toEqual([
        {
          effective_on: firstMonday,
          expenditure_kcal: 2350,
          estimated_at: Date.now(),
          deviation_direction: "negative",
          reviewed_at: Date.now(),
        },
      ]);
    });

    test("今の目標に、その月曜から当てる1日の目安を、主な理由とともに書くこと", async () => {
      expect(await readReviewedDailyGuides()).toEqual([
        {
          goal_id: goalId,
          effective_on: firstMonday,
          energy_kcal: 2350,
          protein_g: 110,
          fat_g: 65,
          carbohydrate_g: 330,
          main_reason: "expenditure_change",
        },
      ]);
    });

    test("推定消費カロリー、1日の目安、週の見直しの順に、その応答の変更で届くこと", () => {
      expect(
        pulled.changes
          .filter(({ kind }) =>
            ["expenditure_estimate", "daily_guide", "weekly_review"].includes(kind),
          )
          .map(({ kind, record }) => ({ kind, effectiveOn: record["effectiveOn"] })),
      ).toEqual([
        { kind: "expenditure_estimate", effectiveOn: firstMonday },
        { kind: "daily_guide", effectiveOn: firstMonday },
        { kind: "weekly_review", effectiveOn: firstMonday },
      ]);
    });
  });

  describe("見直せる週の月曜に、その月曜から維持の目標に立て直したとき", () => {
    let decision: { status: string };
    beforeEach(async () => {
      await recordFirstWeek();
      // 見直しのあとの推定 2,350 kcal と、その月曜の体重の傾向 70 kg で出した値を見せていた
      decision = await (
        await postGoalSetup(sessionToken, "decisions", {
          requestId: generateRecordId(),
          startedOn: firstMonday,
          choice: { type: "maintain" },
          shown: {
            targetWeightKg: 70,
            dailyGuide: { energyKcal: 2350, proteinG: 110, fatG: 65, carbohydrateG: 330 },
          },
          rejectedCustomTargetWeightCount: 0,
        })
      ).json();
    });

    test("その月曜の見直しは前の目標に、新しい目標の1日の目安はその月曜から当てること", async () => {
      const dailyGuidesOnMonday = await readRows(
        accountId,
        `SELECT g.goal_id = '${goalId}' AS is_previous_goal, r.main_reason IS NOT NULL AS is_reviewed FROM daily_guides g LEFT JOIN reviewed_daily_guides r ON r.daily_guide_id = g.id WHERE g.effective_on = '${firstMonday}' ORDER BY is_previous_goal DESC`,
      );
      expect({ status: decision.status, dailyGuidesOnMonday }).toEqual({
        status: "decided",
        dailyGuidesOnMonday: [
          { is_previous_goal: 1, is_reviewed: 1 },
          { is_previous_goal: 0, is_reviewed: 0 },
        ],
      });
    });
  });

  describe("2つの見直せる週のあとの水曜に、初めて取りに行ったとき", () => {
    beforeEach(async () => {
      await recordFirstWeek();
      await recordDailyWeights(sessionToken, daysFrom(firstMonday, 7), 70);
      await recordMealEnergies(accountId, daysFrom(firstMonday, 7), 2200);
      vi.setSystemTime(Date.now() + 9 * millisecondsPerDay);
      await pullSyncChanges(sessionToken);
    });

    test("古い順に見直し、前の週の推定から続けて、見直した時刻がそろうこと", async () => {
      // 2つめの週は、予測した変化が（2,200 − 2,350）× 7 ÷ 7,700 = −0.136 kg で、同じ向きが続いて k は 0.5。
      // 新しい推定は 2,350 − 0.5 × 7,700 × 0.136 ÷ 7 = 2,275 kcal
      expect(
        (await readReviewedEstimates()).map(({ effective_on, expenditure_kcal, reviewed_at }) => ({
          effective_on,
          expenditure_kcal,
          reviewed_at,
        })),
      ).toEqual([
        { effective_on: firstMonday, expenditure_kcal: 2350, reviewed_at: Date.now() },
        { effective_on: addDays(firstMonday, 7), expenditure_kcal: 2275, reviewed_at: Date.now() },
      ]);
    });

    test("前の週の1日の目安から続けて、1週に1つの1日の目安を書くこと", async () => {
      expect(
        (await readReviewedDailyGuides()).map(({ effective_on, energy_kcal }) => ({
          effective_on,
          energy_kcal,
        })),
      ).toEqual([
        { effective_on: firstMonday, energy_kcal: 2350 },
        { effective_on: addDays(firstMonday, 7), energy_kcal: 2300 },
      ]);
    });
  });
});
