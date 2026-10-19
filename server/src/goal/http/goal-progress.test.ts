import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { signInTestAccount } from "../../http/testing";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { updateAccountSettingsWrite } from "../../account-settings/http/testing/update-account-settings-write";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";

const millisecondsPerDay = 86_400_000;

// その日（YYYY-MM-DD）の日本時間の正午に時計を合わせる
const setClockTo = (calendarDay: string) => {
  vi.setSystemTime(Date.parse(`${calendarDay}T03:00:00Z`));
};

// 達成と期限の日の結果の確定を、受け口から確かめる
describe("目標の達成と期限の日の結果", () => {
  let accountId: string;
  let sessionToken: string;
  let goalId: RecordId;
  let goalStartedOn: string;
  // 渡した日ごとに、日本時間の朝 9 時の体重記録を送る
  const sendWeights = async (
    days: readonly string[],
    weightKg: number,
    { isFinalBatch }: { isFinalBatch: boolean },
  ) => {
    const response = await pushSyncWrites(sessionToken, {
      writes: days.map((calendarDay) =>
        createWeightRecordWrite({
          weightRecord: {
            weightKg,
            measuredAt: Date.parse(`${calendarDay}T00:00:00Z`),
            timeZone: "Asia/Tokyo",
          },
        }),
      ),
      isFinalBatch,
    });
    if (response.status !== 200) {
      throw new Error(`体重記録を送れなかった: ${response.status}`);
    }
  };
  const pullGoal = async () =>
    (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
      .filter(({ kind, recordId }) => kind === "goal" && recordId === goalId)
      .at(-1)?.record;

  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    // 時計をサインインの1日あとで止め、その日に、2日後を期限にして 72 kg から 70 kg を目指す減量の目標を立てたことにする
    useFakeClock(Date.now() + millisecondsPerDay);
    goalStartedOn = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    setClockTo(goalStartedOn);
    goalId = generateRecordId();
    await runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
      const factory = durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }));
      await factory.goals.create({
        id: goalId,
        startedOn: goalStartedOn,
        startingWeightTrendKg: 72,
        targetWeightKg: 70,
      });
      await factory.weightChangeGoals.create({
        goalId,
        deadlineOn: addDays(goalStartedOn, 2),
        pacePlan: "standard",
      });
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
      });
    });
  });

  describe("体重記録を送り切り、体重の傾向が目標体重に届いたとき", () => {
    beforeEach(async () => {
      await sendWeights([goalStartedOn], 69.8, { isFinalBatch: true });
    });

    test("その日を達成した日として、判定した時刻とタイムゾーンとともに目標の記録で届くこと", async () => {
      expect((await pullGoal())?.["achievement"]).toEqual({
        achievedOn: goalStartedOn,
        judgedAt: Date.now(),
        timeZone: "Asia/Tokyo",
      });
    });
  });

  describe("目標体重に届く体重記録を、送り切っていない送る要求で送ったとき", () => {
    beforeEach(async () => {
      await sendWeights([goalStartedOn], 69.8, { isFinalBatch: false });
    });

    test("その要求では達成を書かず、次の取りに行く要求で書くこと", async () => {
      const goalBeforePull = await runInDurableObject(
        getAccountDurableObject(env, accountId),
        (_, state) =>
          state.storage.sql
            .exec("SELECT COUNT(*) AS count FROM goal_achievements WHERE goal_id = ?", goalId)
            .one()["count"],
      );
      expect({ goalBeforePull, achievement: (await pullGoal())?.["achievement"] }).toEqual({
        goalBeforePull: 0,
        achievement: expect.objectContaining({ achievedOn: goalStartedOn }),
      });
    });
  });

  describe("期限の日まで目標体重に届かなかったとき", () => {
    beforeEach(async () => {
      await sendWeights([goalStartedOn, addDays(goalStartedOn, 1), addDays(goalStartedOn, 2)], 71, {
        isFinalBatch: true,
      });
    });

    describe("期限の日のうちのとき", () => {
      let goal: Awaited<ReturnType<typeof pullGoal>>;
      beforeEach(async () => {
        setClockTo(addDays(goalStartedOn, 2));
        goal = await pullGoal();
      });

      test("確定しないこと", () => {
        expect(goal?.["deadlineConfirmation"]).toBeUndefined();
      });
    });

    describe("期限の日の翌日のとき", () => {
      let goal: Awaited<ReturnType<typeof pullGoal>>;
      beforeEach(async () => {
        setClockTo(addDays(goalStartedOn, 3));
        goal = await pullGoal();
      });

      test("最初の要求で、期限の日の体重の傾向を確定すること", () => {
        expect(goal?.["deadlineConfirmation"]).toEqual({
          deadlineWeightTrendKg: 71,
          confirmedAt: Date.now(),
          timeZone: "Asia/Tokyo",
        });
      });
    });

    describe("確定のあとに期限の日の体重が遅れて届いたとき", () => {
      let confirmed: unknown;
      let goal: Awaited<ReturnType<typeof pullGoal>>;
      beforeEach(async () => {
        setClockTo(addDays(goalStartedOn, 3));
        confirmed = (await pullGoal())?.["deadlineConfirmation"];
        setClockTo(addDays(goalStartedOn, 4));
        await sendWeights([addDays(goalStartedOn, 2)], 60, { isFinalBatch: true });
        goal = await pullGoal();
      });

      test("確定した値を変えず、達成にもしないこと", () => {
        expect({
          deadlineConfirmation: goal?.["deadlineConfirmation"],
          achievement: goal?.["achievement"],
        }).toEqual({ deadlineConfirmation: confirmed, achievement: undefined });
      });
    });
  });

  describe("利用状況の出来事", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    const readGoalEvents = () =>
      readPostHogCapturedEvents(fetchSpy).filter(({ event }) => event.startsWith("goal_"));
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
    });

    describe("開始の日に目標体重に届いたとき", () => {
      beforeEach(async () => {
        await sendWeights([goalStartedOn], 69.8, { isFinalBatch: true });
      });

      test("開始の日からの日数と、期限までの残りの日数を送ること", () => {
        expect(readGoalEvents()).toEqual([
          {
            event: "goal_achieved",
            distinct_id: accountId,
            properties: { days_from_start: 0, days_until_deadline: 2, $geoip_disable: true },
          },
        ]);
      });
    });

    describe("期限の日まで目標体重に届かず、期限の日の翌日に取りに行ったとき", () => {
      beforeEach(async () => {
        await sendWeights(
          [goalStartedOn, addDays(goalStartedOn, 1), addDays(goalStartedOn, 2)],
          71.04,
          { isFinalBatch: false },
        );
        setClockTo(addDays(goalStartedOn, 3));
        await pullSyncChanges(sessionToken);
      });

      test("期限の日の体重の傾向と目標体重との差を 0.1 kg 単位で、達成していなかったことと一緒に送ること", () => {
        expect(readGoalEvents()).toEqual([
          {
            event: "goal_deadline_confirmed",
            distinct_id: accountId,
            properties: { difference_from_target_kg: 1, achieved: false, $geoip_disable: true },
          },
        ]);
      });

      test("体重の値を含めないこと", () => {
        // 体重（71.04）、目標体重（70）、開始の日の体重の傾向（72）
        expect(JSON.stringify(readGoalEvents())).not.toMatch(/[:,[]"?(?:71\.04|70|72)"?[,}\]]/u);
      });
    });

    describe("期限の日の前に達成し、期限の日の翌日に取りに行ったとき", () => {
      beforeEach(async () => {
        await sendWeights([goalStartedOn], 69.8, { isFinalBatch: true });
        setClockTo(addDays(goalStartedOn, 3));
        await pullSyncChanges(sessionToken);
      });

      test("達成していたことを送ること", () => {
        expect(
          readGoalEvents()
            .filter(({ event }) => event === "goal_deadline_confirmed")
            .map(({ properties }) => properties["achieved"]),
        ).toEqual([true]);
      });
    });

    describe("利用状況を送らない人が、目標体重に届いたとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [updateAccountSettingsWrite({ accountSettings: { sendsUsageData: false } })],
        });
        await sendWeights([goalStartedOn], 69.8, { isFinalBatch: true });
      });

      test("目標の出来事を送らないこと", () => {
        expect(readGoalEvents()).toEqual([]);
      });
    });
  });
});
