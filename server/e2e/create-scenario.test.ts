import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { z } from "zod";
import { app } from "../src/http/app";
import { computeCalendarDayInTimeZone } from "../src/domain/compute-calendar-day-in-time-zone";
import { computeStartOfWeek } from "../src/domain/compute-start-of-week";
import { generateRecordId } from "../src/domain/record-id";
import { createScenario } from "./create-scenario";
import { type DeviceClient, type DeviceSession, createDeviceClient } from "./device-client";
import { computeTodayOfStartedOn, readFreeTrialLastDay } from "./read-free-trial-last-day";

const signInSecret = "e2e-sign-in-secret-0123456789abcdef0123456789";

const goalRecordSchema = z.object({
  id: z.string(),
  weightChange: z.object({ deadlineOn: z.string() }).optional(),
  deadlineConfirmation: z.object({ confirmedAt: z.number() }).optional(),
  closure: z.object({ endReason: z.string(), nextGoalId: z.string() }).optional(),
});

type GoalRecord = z.infer<typeof goalRecordSchema>;

const pullGoals = async (session: DeviceSession): Promise<GoalRecord[]> =>
  (await session.pullAllChanges())
    .filter(({ kind }) => kind === "goal")
    .map(({ record }) => goalRecordSchema.parse(record));

// 場面を作ったあと、アプリの代わりに今の時刻で取りに行き、時の経過で起きる判定がその要求で起きることを確かめる
describe("時の経過で起きる知らせの場面を作る道", () => {
  let client: DeviceClient;
  beforeEach(() => {
    const deployedEnv = {
      ...env,
      SENTRY_ENVIRONMENT: "development",
      E2E_SIGN_IN_SECRET: signInSecret,
    };
    client = createDeviceClient({
      baseUrl: "https://api-dev.example.test",
      signInSecret,
      deviceId: generateRecordId(),
      send: async (url, init) => app.request(url, init, deployedEnv),
    });
  });

  describe("目標の期限を過ぎ、期限のあとの最初の月曜も過ぎた場面のとき", () => {
    // 場面を作り終えた時刻。判定がアプリの最初の要求で起きたことを、これより後の時刻で見分ける
    let createdAt: number;
    let deadlineGoal: GoalRecord;
    let goals: GoalRecord[];
    beforeEach(async () => {
      const session = await createScenario(client, "goal-deadline-passed");
      createdAt = Date.now();
      goals = await pullGoals(session);
      const found = goals.find(({ weightChange }) => weightChange !== undefined);
      if (found === undefined) {
        throw new Error("減量の目標が届かなかった");
      }
      deadlineGoal = found;
    });

    test("最初の取りに行く要求で、減量の目標の期限の日が確定すること", () => {
      expect(deadlineGoal.deadlineConfirmation?.confirmedAt).toBeGreaterThanOrEqual(createdAt);
    });

    test("最初の取りに行く要求で、期限後の維持の目標に移ること", () => {
      const nextGoal = goals.find(({ id }) => id === deadlineGoal.closure?.nextGoalId);
      expect({
        endReason: deadlineGoal.closure?.endReason,
        nextGoalWeightChange: nextGoal?.weightChange,
        nextGoalFound: nextGoal !== undefined,
      }).toEqual({
        endReason: "moved_to_maintenance",
        nextGoalWeightChange: undefined,
        nextGoalFound: true,
      });
    });
  });

  describe("前の週をまだ見直していない場面のとき", () => {
    let effectiveOns: string[];
    beforeEach(async () => {
      const session = await createScenario(client, "unreviewed-week");
      effectiveOns = (await session.pullAllChanges())
        .filter(({ kind }) => kind === "weekly_review")
        .map(({ record }) => z.object({ effectiveOn: z.string() }).parse(record).effectiveOn);
    });

    test("最初の取りに行く要求で、今週の月曜の週の見直しが届くこと", () => {
      expect(effectiveOns).toEqual([
        computeStartOfWeek(computeCalendarDayInTimeZone(new Date(), client.timeZone)),
      ]);
    });
  });

  describe("無料体験が終わった場面のとき", () => {
    let session: DeviceSession;
    beforeEach(async () => {
      session = await createScenario(client, "free-trial-expired");
    });

    test("無料体験の最後の日が今日より前になっていること", async () => {
      expect(await readFreeTrialLastDay(session)).toSatisfy(
        (lastDay) => typeof lastDay === "string" && lastDay < computeTodayOfStartedOn(),
      );
    });
  });
});
