import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { updateAccountSettingsWrite } from "../../account-settings/http/testing/update-account-settings-write";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { enableUsageEventSending } from "../sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { signInTestAccount } from "../testing";
import { postGoalSetup } from "./testing/post-goal-setup";
import { readAllStoredRows } from "./testing/read-all-stored-rows";
import { recordDailyWeights } from "./testing/record-daily-weights";

type Change = { kind: string; recordId: string; record: Record<string, unknown> };
type Decision = { status: string; changes?: Change[] };

describe("目標を決める要求", () => {
  let accountId: string;
  let sessionToken: string;
  // 端末のタイムゾーン（日本時間）での今日
  let today: string;
  // 初期値の窓（今日を除く直前の 28 日）
  let windowDays: string[];
  // 開始の日から数えて 91 日め（13 週）の期限
  let deadlineOn: string;
  let pullChanges: () => Promise<Change[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    // 時計を、サインインのちょうど1日あとで止める。使い始めた日が昨日になり、準備と要求のあいだに日付が変わらない
    useFakeClock(Date.now() + 86_400_000);
    today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    windowDays = Array.from({ length: 28 }, (_, index) => addDays(today, index - 28));
    deadlineOn = addDays(today, 90);
    pullChanges = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter(({ kind }) => ["goal", "daily_guide", "expenditure_estimate"].includes(kind))
        .map(({ kind, recordId, record }) => ({ kind, recordId, record }));
  });

  describe("初めての目標で、体重が 70 kg のまま、使い始める前の摂取エネルギーが毎日 2,400 kcal のとき", () => {
    // 逆算した推定消費カロリーは 2,400 kcal。標準の案は 65.5 kg、1日の目安 2,000 kcal
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    let standardDecision: Record<string, unknown>;
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 }));
      standardDecision = {
        requestId: generateRecordId(),
        startedOn: today,
        choice: { type: "proposal", direction: "lose", deadlineOn, pace: "standard" },
        shown: {
          targetWeightKg: 65.5,
          dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
        },
        rejectedCustomTargetWeightCount: 0,
        preUseEnergyIntakes,
      };
    });

    describe("見せていた標準の案で決めたとき", () => {
      let response: Response;
      let decision: Decision;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", standardDecision);
        decision = await response.clone().json<Decision>();
      });

      test("目標・1日の目安・推定消費カロリーの記録を、この順に返すこと", () => {
        const [goal, dailyGuide, estimate] = decision.changes ?? [];
        expect({ status: response.status, body: decision }).toEqual({
          status: 200,
          body: {
            status: "decided",
            changes: [
              {
                kind: "goal",
                recordId: goal?.recordId,
                record: {
                  id: goal?.recordId,
                  startedOn: today,
                  startingWeightTrendKg: 70,
                  targetWeightKg: 65.5,
                  decidedAt: Date.now(),
                  timeZone: "Asia/Tokyo",
                  direction: "lose",
                  weightChange: { deadlineOn, pacePlan: "standard" },
                },
              },
              {
                kind: "daily_guide",
                recordId: dailyGuide?.recordId,
                record: {
                  id: dailyGuide?.recordId,
                  goalId: goal?.recordId,
                  expenditureEstimateId: estimate?.recordId,
                  effectiveOn: today,
                  energyKcal: 2000,
                  proteinG: 105,
                  fatG: 55,
                  carbohydrateG: 270,
                  limitHits: [],
                },
              },
              {
                kind: "expenditure_estimate",
                recordId: estimate?.recordId,
                record: {
                  id: estimate?.recordId,
                  effectiveOn: today,
                  expenditureKcal: 2400,
                  estimatedAt: Date.now(),
                  initialSource: "back_calculated",
                },
              },
            ],
          },
        });
      });

      test("同じ記録が、同じ順で同期に出ること", async () => {
        expect(await pullChanges()).toEqual(decision.changes);
      });

      test("減量の目標の行と、推定の始まりの行と、要求の受け取りを書くこと", async () => {
        expect(
          await readRows(
            accountId,
            `SELECT
              (SELECT pace_plan FROM weight_change_goals) AS pace_plan,
              (SELECT source FROM initial_expenditure_estimates) AS source,
              (SELECT id FROM goal_decision_receipts) AS receipt_id,
              (SELECT count(*) FROM goal_closures) AS closure_count`,
          ),
        ).toEqual([
          {
            pace_plan: "standard",
            source: "back_calculated",
            receipt_id: standardDecision["requestId"],
            closure_count: 0,
          },
        ]);
      });

      describe("同じ要求の ID で、体重が変わったあとにもう一度送ったとき", () => {
        let resent: Response;
        beforeEach(async () => {
          // 計算し直せば、見せていた値と違う案になる体重
          await recordDailyWeights(sessionToken, [today], 90);
          resent = await postGoalSetup(sessionToken, "decisions", standardDecision);
        });

        test("初めての応答と同じ形で返すこと", async () => {
          expect(await resent.json()).toEqual(decision);
        });

        test("目標も、同期の変更も足さないこと", async () => {
          expect({
            goals: await readRows(accountId, "SELECT count(*) AS count FROM goals"),
            changes: await pullChanges(),
          }).toEqual({ goals: [{ count: 1 }], changes: decision.changes });
        });
      });

      describe("続けて、見せていた維持の目標で立て直したとき", () => {
        let secondDecision: Decision;
        beforeEach(async () => {
          const second = await postGoalSetup(sessionToken, "decisions", {
            requestId: generateRecordId(),
            startedOn: today,
            choice: { type: "maintain" },
            shown: {
              targetWeightKg: 70,
              dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
            },
            rejectedCustomTargetWeightCount: 0,
            // 立て直すときは使わないので、逆算すれば違う値になる摂取エネルギーを添えても、今の推定のままになる
            preUseEnergyIntakes: windowDays.map((calendarDay) => ({ calendarDay, kcal: 3000 })),
          });
          secondDecision = await second.json<Decision>();
        });

        test("閉じた前の目標、新しい目標、今の推定を指す1日の目安を、この順に返すこと", () => {
          const [firstGoal, , firstEstimate] = decision.changes ?? [];
          const [closedGoal, newGoal, dailyGuide] = secondDecision.changes ?? [];
          expect(secondDecision).toEqual({
            status: "decided",
            changes: [
              {
                kind: "goal",
                recordId: firstGoal?.recordId,
                record: {
                  ...firstGoal?.record,
                  closure: { endedOn: today, nextGoalId: newGoal?.recordId },
                },
              },
              {
                kind: "goal",
                recordId: newGoal?.recordId,
                record: {
                  id: newGoal?.recordId,
                  startedOn: today,
                  startingWeightTrendKg: 70,
                  targetWeightKg: 70,
                  decidedAt: Date.now(),
                  timeZone: "Asia/Tokyo",
                  direction: "maintain",
                },
              },
              {
                kind: "daily_guide",
                recordId: dailyGuide?.recordId,
                record: {
                  id: dailyGuide?.recordId,
                  goalId: newGoal?.recordId,
                  expenditureEstimateId: firstEstimate?.recordId,
                  effectiveOn: today,
                  energyKcal: 2400,
                  proteinG: 110,
                  fatG: 65,
                  carbohydrateG: 345,
                  limitHits: [],
                },
              },
            ],
          });
          expect(closedGoal?.recordId).toBe(firstGoal?.recordId);
        });

        test("閉じた前の目標の記録が、新しい目標より先に同期に出ること", async () => {
          const [, firstDailyGuide, firstEstimate] = decision.changes ?? [];
          expect(await pullChanges()).toEqual([
            firstDailyGuide,
            firstEstimate,
            ...(secondDecision.changes ?? []),
          ]);
        });

        test("推定を作らず、維持の目標に減量・増量の行を書かず、閉じていない目標を1つにすること", async () => {
          expect(
            await readRows(
              accountId,
              `SELECT
                (SELECT count(*) FROM expenditure_estimates) AS estimate_count,
                (SELECT count(*) FROM weight_change_goals) AS weight_change_goal_count,
                (SELECT count(*) FROM goals WHERE id NOT IN (SELECT goal_id FROM goal_closures)) AS current_goal_count`,
            ),
          ).toEqual([{ estimate_count: 1, weight_change_goal_count: 1, current_goal_count: 1 }]);
        });
      });
    });

    describe("見せていた維持の目標で決めたとき", () => {
      let decision: Decision;
      beforeEach(async () => {
        const response = await postGoalSetup(sessionToken, "decisions", {
          ...standardDecision,
          choice: { type: "maintain" },
          shown: {
            targetWeightKg: 70,
            dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
          },
        });
        decision = await response.json<Decision>();
      });

      test("期限と速さの案を持たない、維持の目標の記録を返すこと", () => {
        expect(decision.changes?.[0]?.record).toEqual({
          id: decision.changes?.[0]?.recordId,
          startedOn: today,
          startingWeightTrendKg: 70,
          targetWeightKg: 70,
          decidedAt: Date.now(),
          timeZone: "Asia/Tokyo",
          direction: "maintain",
        });
      });

      test("減量・増量の行を書かないこと", async () => {
        expect(await readRows(accountId, "SELECT goal_id FROM weight_change_goals")).toEqual([]);
      });
    });

    describe("受け付ける幅の中の、自分で決めた目標体重で決めたとき", () => {
      let decision: Decision;
      beforeEach(async () => {
        const response = await postGoalSetup(sessionToken, "decisions", {
          ...standardDecision,
          choice: { type: "custom", direction: "lose", deadlineOn, targetWeightKg: 65 },
          shown: {
            targetWeightKg: 65,
            dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
          },
        });
        decision = await response.json<Decision>();
      });

      test("速さの案を、自分で決めた目標体重にして決めること", () => {
        expect(decision.changes?.[0]?.record).toMatchObject({
          targetWeightKg: 65,
          direction: "lose",
          weightChange: { deadlineOn, pacePlan: "custom" },
        });
      });
    });

    describe("ハード案より速い、自分で決めた目標体重で決めようとしたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", {
          ...standardDecision,
          choice: { type: "custom", direction: "lose", deadlineOn, targetWeightKg: 60 },
          shown: {
            targetWeightKg: 60,
            dailyGuide: { energyKcal: 1800, proteinG: 95, fatG: 50, carbohydrateG: 245 },
          },
        });
      });

      test("決めずに、いちばん近い目標体重と理由を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: {
            status: "custom_target_weight_rejected",
            startedOn: today,
            rejectionReason: "pace_too_fast",
            nearestAcceptedTargetWeightKg: 63.2,
          },
        });
      });

      test("目標も受け取りも書かないこと", async () => {
        expect(await readDecisionRowIds(accountId)).toEqual([]);
      });
    });

    describe("見せていた値を出したあとに体重が変わっていたとき", () => {
      let response: Response;
      beforeEach(async () => {
        // 今日の体重で、開始の日の体重の傾向が 70 kg から変わる
        await recordDailyWeights(sessionToken, [today], 72);
        response = await postGoalSetup(sessionToken, "decisions", standardDecision);
      });

      test("決めずに、新しい体重の傾向で出した目標案を、目標案の応答と同じ形で返すこと", async () => {
        const proposals = await (
          await postGoalSetup(sessionToken, "proposals", {
            direction: "lose",
            deadlineOn,
            preUseEnergyIntakes,
          })
        ).json<{ startingWeightTrendKg: number; lastWeightRecordedOn: string }>();
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { status: "recalculated", proposals },
        });
        expect(proposals).toMatchObject({ lastWeightRecordedOn: today });
        expect(proposals.startingWeightTrendKg).toBeGreaterThan(70);
      });

      test("目標も受け取りも書かないこと", async () => {
        expect(await readDecisionRowIds(accountId)).toEqual([]);
      });

      describe("同じ要求の ID で、新しい案の値を見せて送り直したとき", () => {
        let resent: Response;
        beforeEach(async () => {
          const { proposals } = await response.clone().json<{
            proposals: {
              proposals: { pace: string; targetWeightKg: number; dailyGuide: unknown }[];
            };
          }>();
          const standard = proposals.proposals.find(({ pace }) => pace === "standard");
          resent = await postGoalSetup(sessionToken, "decisions", {
            ...standardDecision,
            shown: { targetWeightKg: standard?.targetWeightKg, dailyGuide: standard?.dailyGuide },
          });
        });

        test("計算し直して決めること", async () => {
          expect(await resent.json()).toMatchObject({ status: "decided" });
        });
      });
    });

    describe("開始の日が、サーバーの出した開始の日と違うとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", {
          ...standardDecision,
          startedOn: addDays(today, -1),
        });
      });

      test("決めずに、今日を開始の日にした目標案を返すこと", async () => {
        expect(await response.json()).toMatchObject({
          status: "recalculated",
          proposals: { startedOn: today, direction: "lose", deadlineOn },
        });
      });

      test("目標も受け取りも書かないこと", async () => {
        expect(await readDecisionRowIds(accountId)).toEqual([]);
      });
    });

    describe("本番のサーバーで", () => {
      let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
      beforeEach(async () => {
        await enableUsageEventSending(accountId);
        fetchSpy = mockPostHogCaptureEndpointOk();
      });

      describe("端の値に2回直したあとの、自分で決めた目標体重で決めたとき", () => {
        beforeEach(async () => {
          await postGoalSetup(sessionToken, "decisions", {
            ...standardDecision,
            choice: { type: "custom", direction: "lose", deadlineOn, targetWeightKg: 65 },
            shown: {
              targetWeightKg: 65,
              dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
            },
            rejectedCustomTargetWeightCount: 2,
          });
        });

        test("向き・初めてか・選んだ案・速さを落とした案があったか・受け付けなかった数・出どころ・当たった上限と下限を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
            {
              event: "goal_decision_recorded",
              distinct_id: accountId,
              properties: {
                direction: "lose",
                is_first_goal: true,
                chosen_plan: "custom",
                had_slowed_proposal: false,
                rejected_custom_target_weight_count: 2,
                expenditure_source: "back_calculated",
                limit_hits: [],
                $geoip_disable: true,
              },
            },
          ]);
        });

        describe("続けて、維持の目標で立て直したとき", () => {
          beforeEach(async () => {
            fetchSpy.mockClear();
            await postGoalSetup(sessionToken, "decisions", {
              ...standardDecision,
              requestId: generateRecordId(),
              choice: { type: "maintain" },
              shown: {
                targetWeightKg: 70,
                dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
              },
            });
          });

          test("立て直しと、推定消費カロリーの出どころが前の値であることを送ること", () => {
            expect(readPostHogCapturedEvents(fetchSpy).map(({ properties }) => properties)).toEqual(
              [
                {
                  direction: "maintain",
                  is_first_goal: false,
                  chosen_plan: "maintain",
                  had_slowed_proposal: false,
                  rejected_custom_target_weight_count: 0,
                  expenditure_source: "previous",
                  limit_hits: [],
                  $geoip_disable: true,
                },
              ],
            );
          });
        });
      });

      describe("標準の案で決め、同じ要求の ID でもう一度送ったとき", () => {
        beforeEach(async () => {
          await postGoalSetup(sessionToken, "decisions", standardDecision);
          await postGoalSetup(sessionToken, "decisions", standardDecision);
        });

        test("出来事を1つだけ送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "goal_decision_recorded",
          ]);
        });

        test("出来事に、体重と kcal の値を含めないこと", () => {
          // 体重の傾向（70）、目標体重（65.5）、推定消費カロリー（2400）、1日の目安（2000）と P・F・C（105・55・270）
          expect(JSON.stringify(readPostHogCapturedEvents(fetchSpy))).not.toMatch(
            /[:,[]"?(?:70|65\.5|2400|2000|105|55|270)"?[,}\]]/u,
          );
        });
      });

      describe("決めずに新しい案を返したとき", () => {
        beforeEach(async () => {
          await postGoalSetup(sessionToken, "decisions", {
            ...standardDecision,
            startedOn: addDays(today, -1),
          });
        });

        test("送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("利用状況を送らない設定の人が決めたとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, {
            writes: [updateAccountSettingsWrite({ accountSettings: { sendsUsageData: false } })],
          });
          fetchSpy.mockClear();
          await postGoalSetup(sessionToken, "decisions", standardDecision);
        });

        test("送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });
    });
  });

  describe("初めての目標で、逆算した推定消費カロリーが下限の 1,200 kcal に近いとき", () => {
    // 標準とハードの案は、1日の目安が下限を下回るので出せない。ゆるめの案は速さを落として 68.9 kg
    let decision: Record<string, unknown>;
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      decision = {
        requestId: generateRecordId(),
        startedOn: today,
        choice: { type: "proposal", direction: "lose", deadlineOn, pace: "gentle" },
        shown: {
          targetWeightKg: 68.9,
          dailyGuide: { energyKcal: 1200, proteinG: 105, fatG: 35, carbohydrateG: 115 },
        },
        rejectedCustomTargetWeightCount: 0,
        preUseEnergyIntakes: windowDays.map((calendarDay) => ({ calendarDay, kcal: 1300 })),
      };
    });

    describe("出せない標準の案で決めようとしたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", {
          ...decision,
          choice: { type: "proposal", direction: "lose", deadlineOn, pace: "standard" },
        });
      });

      test("決めずに、新しい案を返すこと", async () => {
        expect(await response.json()).toMatchObject({
          status: "recalculated",
          proposals: {
            proposals: [
              { pace: "gentle", status: "offered" },
              { pace: "standard", status: "unavailable" },
              { pace: "hard", status: "unavailable" },
            ],
          },
        });
      });
    });

    describe("本番のサーバーで、速さを落としたゆるめの案で決めたとき", () => {
      let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
      beforeEach(async () => {
        await enableUsageEventSending(accountId);
        fetchSpy = mockPostHogCaptureEndpointOk();
        await postGoalSetup(sessionToken, "decisions", decision);
      });

      test("速さを落とした案があったことを送ること", () => {
        expect(
          readPostHogCapturedEvents(fetchSpy).map(({ properties }) => ({
            chosenPlan: properties["chosen_plan"],
            hadSlowedProposal: properties["had_slowed_proposal"],
          })),
        ).toEqual([{ chosenPlan: "gentle", hadSlowedProposal: true }]);
      });
    });
  });

  describe("西へ移ったあとで、今の目標の開始の日が端末の今日より後のとき", () => {
    let currentGoalStartedOn: string;
    let response: Response;
    beforeEach(async () => {
      currentGoalStartedOn = addDays(today, 1);
      await recordDailyWeights(sessionToken, windowDays, 70);
      await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
        const factory = durableObjectFactory(
          drizzle(state.storage, { schema: durableObjectTables }),
        );
        await factory.goals.create({ startedOn: currentGoalStartedOn });
        await factory.expenditureEstimates.create({
          effectiveOn: currentGoalStartedOn,
          expenditureKcal: 2400,
        });
      });
      response = await postGoalSetup(sessionToken, "decisions", {
        requestId: generateRecordId(),
        startedOn: currentGoalStartedOn,
        choice: { type: "maintain" },
        shown: {
          targetWeightKg: 70,
          dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
        },
        rejectedCustomTargetWeightCount: 0,
      });
    });

    test("新しい目標の開始の日と、1日の目安を当てる始まりの日が、今の目標の開始の日になること", async () => {
      const { changes } = await response.json<Decision>();
      expect(
        changes?.map(({ kind, record }) => ({
          kind,
          day: record["startedOn"] ?? record["effectiveOn"],
        })),
      ).toEqual([
        { kind: "goal", day: currentGoalStartedOn },
        { kind: "goal", day: currentGoalStartedOn },
        { kind: "daily_guide", day: currentGoalStartedOn },
      ]);
    });
  });

  describe("断る要求", () => {
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    let decision: Record<string, unknown>;
    beforeEach(async () => {
      captureExceptionSpy = mockCaptureExceptionOk();
      await recordDailyWeights(sessionToken, windowDays, 70);
      decision = {
        requestId: generateRecordId(),
        startedOn: today,
        choice: { type: "maintain" },
        shown: {
          targetWeightKg: 70,
          dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
        },
        rejectedCustomTargetWeightCount: 0,
        preUseEnergyIntakes: windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 })),
      };
    });

    describe("要求の ID が無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        const { requestId: _, ...withoutRequestId } = decision;
        response = await postGoalSetup(sessionToken, "decisions", withoutRequestId);
      });

      test("形の誤りとして 400 で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 400,
          body: { code: "malformed_request" },
        });
      });

      test("誤っていた場所を Sentry に送ること", () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            name: "GoalSetupRequestMalformedError",
            issues: [{ path: "requestId", code: "invalid_type" }],
          }),
        );
      });
    });

    describe("期限が開始の日から数えて 27 日めのとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", {
          ...decision,
          choice: {
            type: "proposal",
            direction: "lose",
            deadlineOn: addDays(today, 26),
            pace: "standard",
          },
        });
      });

      test("期限が受け付ける幅の外という理由で断り、何も書かないこと", async () => {
        expect({
          status: response.status,
          body: await response.json(),
          rows: await readDecisionRowIds(accountId),
        }).toEqual({ status: 422, body: { code: "deadline_out_of_range" }, rows: [] });
      });
    });

    describe("身体データの身長が範囲の外のとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "decisions", {
          ...decision,
          bodyData: {
            sex: "male",
            heightCentimeters: 99.9,
            ageYears: 40,
            activity: { type: "level", level: "standing" },
          },
        });
      });

      test("身体データが範囲の外という理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "body_data_out_of_range" },
        });
      });

      test("理由を Sentry に送ること", () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            name: "GoalSetupRequestRejectedError",
            reason: "body_data_out_of_range",
          }),
        );
      });
    });

    describe("セッションが無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(undefined, "decisions", decision);
      });

      test("401 を返すこと", () => {
        expect(response.status).toBe(401);
      });
    });
  });

  describe("本番のサーバーで、身体データと使い始める前の摂取エネルギーを添えて、式の推定消費カロリーで決めたあと", () => {
    let logSpy: ReturnType<typeof vi.spyOn>;
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    let response: Response;
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, [addDays(today, -1)], 70);
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
      logSpy = vi.spyOn(console, "log");
      // ほかの値に紛れない値にする
      const situation = {
        preUseEnergyIntakes: windowDays
          .slice(0, 5)
          .map((calendarDay) => ({ calendarDay, kcal: 2413.7 })),
        bodyData: {
          sex: "female",
          heightCentimeters: 171.3,
          ageYears: 113,
          activity: {
            type: "steps",
            dailySteps: windowDays.map((calendarDay) => ({ calendarDay, steps: 7654 })),
          },
        },
      };
      const { maintenance } = await (
        await postGoalSetup(sessionToken, "proposals", { direction: "maintain", ...situation })
      ).json<{ maintenance: { targetWeightKg: number; dailyGuide: unknown } }>();
      response = await postGoalSetup(sessionToken, "decisions", {
        requestId: generateRecordId(),
        startedOn: today,
        choice: { type: "maintain" },
        shown: maintenance,
        rejectedCustomTargetWeightCount: 0,
        ...situation,
      });
    });

    test("式を出どころにした推定消費カロリーで決めること", async () => {
      const { status, changes } = await response.json<Decision>();
      expect({ status, initialSource: changes?.[2]?.record["initialSource"] }).toEqual({
        status: "decided",
        initialSource: "formula",
      });
    });

    test("DB のどの表にも、身体データと摂取エネルギーの値が無いこと", async () => {
      expect(JSON.stringify(await readAllStoredRows(accountId))).not.toMatch(leftValuePattern);
    });

    test("ログに、身体データと摂取エネルギーの値が無いこと", () => {
      expect(JSON.stringify(logSpy.mock.calls)).not.toMatch(leftValuePattern);
    });

    test("PostHog の出来事に、身体データと摂取エネルギーの値が無いこと", () => {
      const events = readPostHogCapturedEvents(fetchSpy);
      expect(events.map(({ event }) => event)).toEqual(["goal_decision_recorded"]);
      expect(JSON.stringify(events)).not.toMatch(leftValuePattern);
    });
  });
});

// 目標を決めたときに書く表の行の ID。決めなかった要求が何も書いていないことを確かめる
const readDecisionRowIds = (accountId: string) =>
  readRows(
    accountId,
    "SELECT id FROM goals UNION ALL SELECT id FROM expenditure_estimates UNION ALL SELECT id FROM daily_guides UNION ALL SELECT id FROM goal_decision_receipts",
  );

// 添えた摂取エネルギー（2413.7）と身長（171.3）、JSON の値として出る歩数（7654）と年齢（113）。ID や時刻の中の同じ並びは拾わない
const leftValuePattern = /2413\.7|171\.3|[:,[]"?(?:7654|113)"?[,}\]]/u;
