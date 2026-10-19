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

const millisecondsPerDay = 86_400_000;

const daysFrom = (from: string, count: number): string[] =>
  Array.from({ length: count }, (_, offset) => addDays(from, offset));

type Change = Omit<PullResult["changes"][number], "sequence">;

// 期限のあと次の目標を選ばないまま、期限の日より後の最初の月曜が来た人を受け口から確かめる。
// 減量の目標（72 kg → 70 kg）の期限は、目標の開始の日のあとの最初の月曜 M の前の日曜。体重はどの日も 71 kg。
// 推定 2,400 kcal と1日の目安 1,900 kcal（P 120・F 55・C 200）が当たっている
describe("期限後の維持に移る見直し", () => {
  let accountId: string;
  let sessionToken: string;
  let previousGoalId: RecordId;
  let estimateId: RecordId;
  // 期限の日より後の最初の月曜
  let monday: string;
  // 最後に届いた、その記録の変更
  let latestOf: (changes: Change[], kind: string, recordId?: string) => Change | undefined;
  let pullChanges: () => Promise<Change[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    useFakeClock(Date.now() + millisecondsPerDay);
    const goalStartedOn = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    monday = addDays(computeStartOfWeek(goalStartedOn), 7);
    previousGoalId = generateRecordId();
    estimateId = generateRecordId();
    await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
      const factory = durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }));
      await factory.goals.create({
        id: previousGoalId,
        startedOn: goalStartedOn,
        startingWeightTrendKg: 72,
        targetWeightKg: 70,
      });
      await factory.weightChangeGoals.create({
        goalId: previousGoalId,
        deadlineOn: addDays(monday, -1),
        pacePlan: "standard",
      });
      await factory.expenditureEstimates.create({
        id: estimateId,
        effectiveOn: goalStartedOn,
        expenditureKcal: 2400,
      });
      // 推定の始まりは逆算にし、使い始めて7日未満を当てない
      await factory.initialExpenditureEstimates.create({
        expenditureEstimateId: estimateId,
        source: "back_calculated",
      });
      await factory.dailyGuides.create({
        goalId: previousGoalId,
        expenditureEstimateId: estimateId,
        effectiveOn: goalStartedOn,
        energyKcal: 1900,
        proteinG: 120,
        fatG: 55,
        carbohydrateG: 200,
      });
    });
    await recordDailyWeights(sessionToken, daysFrom(addDays(monday, -21), 21), 71);
    latestOf = (changes, kind, recordId) =>
      changes.findLast(
        (change) =>
          change.kind === kind && (recordId === undefined || change.recordId === recordId),
      );
    pullChanges = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes.map(
        ({ kind, recordId, record }) => ({ kind, recordId, record }),
      );
    // M の日本時間の正午
    vi.setSystemTime(Date.parse(`${monday}T03:00:00Z`));
  });

  const readMaintenanceGoalId = async (): Promise<unknown> =>
    (
      await readRows(
        accountId,
        `SELECT next_goal_id FROM goal_closures WHERE goal_id = '${previousGoalId}'`,
      )
    ).at(0)?.["next_goal_id"];

  describe("M の入力の週に食事の記録が無く、見送る週のとき", () => {
    let changes: Change[];
    let maintenanceGoalId: unknown;
    beforeEach(async () => {
      changes = await pullChanges();
      maintenanceGoalId = await readMaintenanceGoalId();
    });

    test("前の目標を M で閉じ、期限後の維持に移ったことが目標の記録で届くこと", () => {
      expect(latestOf(changes, "goal", previousGoalId)?.record["closure"]).toEqual({
        endedOn: monday,
        nextGoalId: maintenanceGoalId,
        endReason: "moved_to_maintenance",
      });
    });

    test("M から、前の日曜の体重の傾向を保つ、期限の無い維持の目標を、見直した時刻に決めること", () => {
      expect(latestOf(changes, "goal", String(maintenanceGoalId))?.record).toEqual({
        id: maintenanceGoalId,
        startedOn: monday,
        startingWeightTrendKg: 71,
        targetWeightKg: 71,
        decidedAt: Date.now(),
        timeZone: "Asia/Tokyo",
        direction: "maintain",
      });
    });

    test("維持の目標に、前の目標の最後の1日の目安を写し、前の推定を指す1日の目安を M から当てること", () => {
      expect(latestOf(changes, "daily_guide")?.record).toMatchObject({
        goalId: maintenanceGoalId,
        expenditureEstimateId: estimateId,
        effectiveOn: monday,
        energyKcal: 1900,
        proteinG: 120,
        fatG: 55,
        carbohydrateG: 200,
        limitHits: [],
      });
    });

    test("推定消費カロリーを新しく出さず、見送りは維持の目標に当てること", async () => {
      expect({
        estimates: await readRows(accountId, "SELECT id FROM expenditure_estimates"),
        deferral: latestOf(changes, "weekly_review")?.record["deferral"],
      }).toEqual({
        estimates: [{ id: estimateId }],
        deferral: { reason: "few_meal_records", goalId: maintenanceGoalId },
      });
    });

    test("閉じた前の目標、維持の目標、1日の目安、週の見直しの順に届くこと", () => {
      expect(
        changes
          .slice(-4)
          .map(({ kind, recordId }) =>
            kind === "goal"
              ? recordId === previousGoalId
                ? "previous_goal"
                : "maintenance_goal"
              : kind,
          ),
      ).toEqual(["previous_goal", "maintenance_goal", "daily_guide", "weekly_review"]);
    });

    test("次の週の見直しでは、もう移らないこと", async () => {
      vi.setSystemTime(Date.now() + 7 * millisecondsPerDay);
      await pullChanges();
      expect(
        await readRows(accountId, "SELECT goal_id FROM post_deadline_maintenance_goals"),
      ).toEqual([{ goal_id: maintenanceGoalId }]);
    });
  });

  describe("M の入力の週に食事を7日とも 2,200 kcal 記録し、見直せる週のとき", () => {
    let changes: Change[];
    let maintenanceGoalId: unknown;
    beforeEach(async () => {
      await recordMealEnergies(accountId, daysFrom(addDays(monday, -7), 7), 2200);
      changes = await pullChanges();
      maintenanceGoalId = await readMaintenanceGoalId();
    });

    test("見直した推定を使い、維持の式で出した1日の目安を、前の週から ±150 kcal に抑えて維持の目標にだけ書くこと", async () => {
      // 新しい推定は 2,400 − 0.25 × 7,700 × 0.18 ÷ 7 = 2,350 kcal。維持の式では 2,350 kcal だが、1,900 + 150 = 2,050 kcal に抑える
      const newEstimateId = latestOf(changes, "expenditure_estimate")?.recordId;
      expect({
        dailyGuide: latestOf(changes, "daily_guide")?.record,
        guidesOnMonday: await readRows(
          accountId,
          `SELECT goal_id FROM daily_guides WHERE effective_on = '${monday}'`,
        ),
      }).toMatchObject({
        dailyGuide: {
          goalId: maintenanceGoalId,
          expenditureEstimateId: newEstimateId,
          effectiveOn: monday,
          energyKcal: 2050,
          limitHits: ["weekly_change"],
        },
        guidesOnMonday: [{ goal_id: maintenanceGoalId }],
      });
    });

    test("推定消費カロリー、閉じた前の目標、維持の目標、1日の目安、週の見直しの順に届くこと", () => {
      expect(
        changes
          .slice(-5)
          .map(({ kind, recordId }) =>
            kind === "goal"
              ? recordId === previousGoalId
                ? "previous_goal"
                : "maintenance_goal"
              : kind,
          ),
      ).toEqual([
        "expenditure_estimate",
        "previous_goal",
        "maintenance_goal",
        "daily_guide",
        "weekly_review",
      ]);
    });
  });

  describe("M に、まだ取りに行かないまま維持の目標を選んで決めたとき", () => {
    let decision: { status: string; changes: Change[] };
    let maintenanceGoalId: unknown;
    beforeEach(async () => {
      // 目標案の要求も、先に期限後の維持に移ってから答える
      const { maintenance } = await (
        await postGoalSetup(sessionToken, "proposals", { plan: { direction: "maintain" } })
      ).json<{ maintenance: { targetWeightKg: number; dailyGuide: unknown } }>();
      maintenanceGoalId = await readMaintenanceGoalId();
      decision = await (
        await postGoalSetup(sessionToken, "decisions", {
          requestId: generateRecordId(),
          startedOn: monday,
          choice: { type: "maintain" },
          shown: maintenance,
          rejectedCustomTargetWeightCount: 0,
        })
      ).json();
    });

    test("先に期限後の維持に移り、決めた目標がその維持の目標を M で閉じること（0日の目標）", async () => {
      expect({
        status: decision.status,
        closedGoal: decision.changes.at(0)?.record,
        closures: await readRows(
          accountId,
          "SELECT c.goal_id, g.started_on AS ended_on FROM goal_closures c JOIN goals g ON g.id = c.next_goal_id ORDER BY g.decided_at",
        ),
      }).toMatchObject({
        status: "decided",
        closedGoal: {
          id: maintenanceGoalId,
          startedOn: monday,
          closure: { endedOn: monday, endReason: "switched" },
        },
        closures: [
          { goal_id: previousGoalId, ended_on: monday },
          { goal_id: maintenanceGoalId, ended_on: monday },
        ],
      });
    });
  });
});
