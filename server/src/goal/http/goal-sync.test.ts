import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import { createRecordChangeWriter } from "../../durable-object/create-record-change-writer";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { signInTestAccount } from "../../http/testing";

type Factory = ReturnType<typeof durableObjectFactory>;
type Change = Parameters<RecordChangeWrites["addChange"]>[0];

// 目標・1日の目安・推定消費カロリーはサーバーだけが書く。記録の形を1つずつ確かめるので、表に行を置き、記録の変化を書く入口で変更を足す（目標を決める要求から出ることは decide-goal.test.ts）
describe("目標・1日の目安・推定消費カロリーの同期", () => {
  let sessionToken: string;
  // 行を置き、返した記録を変更の並びに足す
  let seed: (rows: (factory: Factory) => Promise<Change[]>) => Promise<void>;
  let pullChanges: () => Promise<Omit<PullResult["changes"][number], "sequence">[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    const signedIn = await signInTestAccount(generateRecordId());
    sessionToken = signedIn.sessionToken;
    seed = (rows) =>
      runInDurableObject(getAccountDurableObject(env, signedIn.accountId), async (_, state) => {
        const changes = await rows(
          durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })),
        );
        createRecordChangeWriter(state.storage)(({ addChange }) => {
          for (const change of changes) {
            addChange(change);
          }
        });
      });
    pullChanges = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes.map(
        ({ kind, recordId, record }) => ({ kind, recordId, record }),
      );
  });

  describe("維持の目標があるとき", () => {
    let goalId: RecordId;
    beforeEach(async () => {
      goalId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({
          id: goalId,
          startedOn: "2026-10-01",
          startingWeightTrendKg: 65,
          targetWeightKg: 65,
          decidedAt: new Date("2026-10-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
        });
        return [{ recordType: "goal", recordId: goalId }];
      });
    });

    test("向きが維持で、期限と速さの案も終わりも持たない目標が届くこと", async () => {
      expect(await pullChanges()).toEqual([
        {
          kind: "goal",
          recordId: goalId,
          record: {
            id: goalId,
            startedOn: "2026-10-01",
            startingWeightTrendKg: 65,
            targetWeightKg: 65,
            decidedAt: Date.parse("2026-10-01T03:00:00Z"),
            timeZone: "Asia/Tokyo",
            direction: "maintain",
          },
        },
      ]);
    });
  });

  describe("目標体重が開始の日の体重の傾向より小さい、期限のある目標があるとき", () => {
    let goalId: RecordId;
    beforeEach(async () => {
      goalId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({
          id: goalId,
          startedOn: "2026-10-01",
          startingWeightTrendKg: 72.4,
          targetWeightKg: 68,
          decidedAt: new Date("2026-10-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.weightChangeGoals.create({
          goalId,
          deadlineOn: "2026-12-24",
          pacePlan: "standard",
        });
        return [{ recordType: "goal", recordId: goalId }];
      });
    });

    test("向きが減量で、期限と速さの案を持つ目標が届くこと", async () => {
      expect(await pullChanges()).toEqual([
        {
          kind: "goal",
          recordId: goalId,
          record: {
            id: goalId,
            startedOn: "2026-10-01",
            startingWeightTrendKg: 72.4,
            targetWeightKg: 68,
            decidedAt: Date.parse("2026-10-01T03:00:00Z"),
            timeZone: "Asia/Tokyo",
            direction: "lose",
            weightChange: { deadlineOn: "2026-12-24", pacePlan: "standard" },
          },
        },
      ]);
    });
  });

  describe("目標体重が開始の日の体重の傾向より大きい目標を、次の目標で閉じたとき", () => {
    let closedGoalId: RecordId;
    let nextGoalId: RecordId;
    beforeEach(async () => {
      closedGoalId = generateRecordId();
      nextGoalId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({
          id: closedGoalId,
          startedOn: "2026-10-01",
          startingWeightTrendKg: 55,
          targetWeightKg: 58.5,
          decidedAt: new Date("2026-10-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.weightChangeGoals.create({
          goalId: closedGoalId,
          deadlineOn: "2027-01-31",
          pacePlan: "custom",
        });
        await factory.goals.create({
          id: nextGoalId,
          startedOn: "2026-10-20",
          startingWeightTrendKg: 56,
          targetWeightKg: 56,
          decidedAt: new Date("2026-10-20T10:00:00Z"),
          timeZone: "America/Los_Angeles",
        });
        await factory.goalClosures.create({ goalId: closedGoalId, nextGoalId });
        // 立て直しでは、閉じた前の目標の変更を新しい目標の変更より先に足す
        return [
          { recordType: "goal", recordId: closedGoalId },
          { recordType: "goal", recordId: nextGoalId },
        ];
      });
    });

    test("閉じた目標が、向きが増量で、次の目標の開始の日を終わった日として、次の目標の ID と、切り替えの終わり方と一緒に届くこと", async () => {
      const [closed] = await pullChanges();
      expect(closed).toEqual({
        kind: "goal",
        recordId: closedGoalId,
        record: {
          id: closedGoalId,
          startedOn: "2026-10-01",
          startingWeightTrendKg: 55,
          targetWeightKg: 58.5,
          decidedAt: Date.parse("2026-10-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
          direction: "gain",
          weightChange: { deadlineOn: "2027-01-31", pacePlan: "custom" },
          closure: { endedOn: "2026-10-20", nextGoalId, endReason: "switched" },
        },
      });
    });

    test("次の目標が、終わりを持たずに、閉じた目標のあとに届くこと", async () => {
      const [, next] = await pullChanges();
      expect(next).toEqual({
        kind: "goal",
        recordId: nextGoalId,
        record: {
          id: nextGoalId,
          startedOn: "2026-10-20",
          startingWeightTrendKg: 56,
          targetWeightKg: 56,
          decidedAt: Date.parse("2026-10-20T10:00:00Z"),
          timeZone: "America/Los_Angeles",
          direction: "maintain",
        },
      });
    });
  });

  describe("達成して期限の日が確定した減量の目標を、期限後の維持の目標で閉じたとき", () => {
    let closedGoalId: RecordId;
    let maintenanceGoalId: RecordId;
    beforeEach(async () => {
      closedGoalId = generateRecordId();
      maintenanceGoalId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({
          id: closedGoalId,
          startedOn: "2026-08-01",
          startingWeightTrendKg: 72,
          targetWeightKg: 68,
          decidedAt: new Date("2026-08-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.weightChangeGoals.create({
          goalId: closedGoalId,
          deadlineOn: "2026-10-11",
          pacePlan: "standard",
        });
        await factory.goalAchievements.create({
          goalId: closedGoalId,
          achievedOn: "2026-10-03",
          judgedAt: new Date("2026-10-04T23:00:00Z"),
          timeZone: "America/Los_Angeles",
        });
        await factory.goalDeadlineConfirmations.create({
          goalId: closedGoalId,
          deadlineWeightTrendKg: 67.8,
          confirmedAt: new Date("2026-10-12T00:30:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.goals.create({
          id: maintenanceGoalId,
          startedOn: "2026-10-12",
          startingWeightTrendKg: 67.8,
          targetWeightKg: 67.8,
          decidedAt: new Date("2026-10-12T00:30:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.goalClosures.create({ goalId: closedGoalId, nextGoalId: maintenanceGoalId });
        await factory.postDeadlineMaintenanceGoals.create({ goalId: maintenanceGoalId });
        return [
          { recordType: "goal", recordId: closedGoalId },
          { recordType: "goal", recordId: maintenanceGoalId },
        ];
      });
    });

    test("閉じた目標が、達成と期限の日の確定と、期限後の維持に移った終わり方と一緒に届くこと", async () => {
      const [closed] = await pullChanges();
      expect(closed).toEqual({
        kind: "goal",
        recordId: closedGoalId,
        record: {
          id: closedGoalId,
          startedOn: "2026-08-01",
          startingWeightTrendKg: 72,
          targetWeightKg: 68,
          decidedAt: Date.parse("2026-08-01T03:00:00Z"),
          timeZone: "Asia/Tokyo",
          direction: "lose",
          weightChange: { deadlineOn: "2026-10-11", pacePlan: "standard" },
          achievement: {
            achievedOn: "2026-10-03",
            judgedAt: Date.parse("2026-10-04T23:00:00Z"),
            timeZone: "America/Los_Angeles",
          },
          deadlineConfirmation: {
            deadlineWeightTrendKg: 67.8,
            confirmedAt: Date.parse("2026-10-12T00:30:00Z"),
            timeZone: "Asia/Tokyo",
          },
          closure: {
            endedOn: "2026-10-12",
            nextGoalId: maintenanceGoalId,
            endReason: "moved_to_maintenance",
          },
        },
      });
    });

    test("期限後の維持の目標が、達成も確定も終わりも持たずに届くこと", async () => {
      const [, maintenance] = await pullChanges();
      expect(maintenance).toEqual({
        kind: "goal",
        recordId: maintenanceGoalId,
        record: {
          id: maintenanceGoalId,
          startedOn: "2026-10-12",
          startingWeightTrendKg: 67.8,
          targetWeightKg: 67.8,
          decidedAt: Date.parse("2026-10-12T00:30:00Z"),
          timeZone: "Asia/Tokyo",
          direction: "maintain",
        },
      });
    });
  });

  describe("逆算で出した推定の始まりと、あとの推定があるとき", () => {
    let initialEstimateId: RecordId;
    let laterEstimateId: RecordId;
    beforeEach(async () => {
      initialEstimateId = generateRecordId();
      laterEstimateId = generateRecordId();
      await seed(async (factory) => {
        await factory.expenditureEstimates.create({
          id: initialEstimateId,
          effectiveOn: "2026-10-01",
          expenditureKcal: 2250,
          estimatedAt: new Date("2026-10-01T03:00:00Z"),
        });
        await factory.initialExpenditureEstimates.create({
          expenditureEstimateId: initialEstimateId,
          source: "back_calculated",
        });
        await factory.expenditureEstimates.create({
          id: laterEstimateId,
          effectiveOn: "2026-10-05",
          expenditureKcal: 2180,
          estimatedAt: new Date("2026-10-05T00:30:00Z"),
        });
        return [
          { recordType: "expenditure_estimate", recordId: initialEstimateId },
          { recordType: "expenditure_estimate", recordId: laterEstimateId },
        ];
      });
    });

    test("推定の始まりが出どころつきで、あとの推定が出どころなしで届くこと", async () => {
      expect(await pullChanges()).toEqual([
        {
          kind: "expenditure_estimate",
          recordId: initialEstimateId,
          record: {
            id: initialEstimateId,
            effectiveOn: "2026-10-01",
            expenditureKcal: 2250,
            estimatedAt: Date.parse("2026-10-01T03:00:00Z"),
            initialSource: "back_calculated",
          },
        },
        {
          kind: "expenditure_estimate",
          recordId: laterEstimateId,
          record: {
            id: laterEstimateId,
            effectiveOn: "2026-10-05",
            expenditureKcal: 2180,
            estimatedAt: Date.parse("2026-10-05T00:30:00Z"),
          },
        },
      ]);
    });
  });

  describe("式で出した推定の始まりがあるとき", () => {
    let estimateId: RecordId;
    beforeEach(async () => {
      estimateId = generateRecordId();
      await seed(async (factory) => {
        await factory.expenditureEstimates.create({ id: estimateId });
        await factory.initialExpenditureEstimates.create({
          expenditureEstimateId: estimateId,
          source: "formula",
        });
        return [{ recordType: "expenditure_estimate", recordId: estimateId }];
      });
    });

    test("出どころが式で届くこと", async () => {
      const [change] = await pullChanges();
      expect(change?.record["initialSource"]).toBe("formula");
    });
  });

  describe("下限と1週の変化に当たった1日の目安と、何にも当たらない1日の目安があるとき", () => {
    let goalId: RecordId;
    let estimateId: RecordId;
    let limitedGuideId: RecordId;
    let freeGuideId: RecordId;
    beforeEach(async () => {
      goalId = generateRecordId();
      estimateId = generateRecordId();
      limitedGuideId = generateRecordId();
      freeGuideId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({ id: goalId, startedOn: "2026-10-01" });
        await factory.expenditureEstimates.create({ id: estimateId });
        await factory.dailyGuides.create({
          id: freeGuideId,
          goalId,
          expenditureEstimateId: estimateId,
          effectiveOn: "2026-10-01",
          energyKcal: 1750,
          proteinG: 115,
          fatG: 50,
          carbohydrateG: 210,
        });
        await factory.dailyGuides.create({
          id: limitedGuideId,
          goalId,
          expenditureEstimateId: estimateId,
          effectiveOn: "2026-10-05",
          energyKcal: 1200,
          proteinG: 105,
          fatG: 35,
          carbohydrateG: 115,
        });
        // 決まりの並び（1週の変化、必要な速さの上限、下限）と逆の順に置く
        await factory.dailyGuideLimitHits.create({
          dailyGuideId: limitedGuideId,
          limitType: "minimum_energy",
        });
        await factory.dailyGuideLimitHits.create({
          dailyGuideId: limitedGuideId,
          limitType: "weekly_change",
        });
        return [
          { recordType: "daily_guide", recordId: freeGuideId },
          { recordType: "daily_guide", recordId: limitedGuideId },
        ];
      });
    });

    test("何にも当たらない1日の目安が、目標と推定の ID、当てる始まりの日、kcal と P・F・C、空の並びで届くこと", async () => {
      const [free] = await pullChanges();
      expect(free).toEqual({
        kind: "daily_guide",
        recordId: freeGuideId,
        record: {
          id: freeGuideId,
          goalId,
          expenditureEstimateId: estimateId,
          effectiveOn: "2026-10-01",
          energyKcal: 1750,
          proteinG: 115,
          fatG: 50,
          carbohydrateG: 210,
          limitHits: [],
        },
      });
    });

    test("当たった上限と下限が、当たったものだけ、決まりの並びの順で届くこと", async () => {
      const [, limited] = await pullChanges();
      expect(limited?.record["limitHits"]).toEqual(["weekly_change", "minimum_energy"]);
    });
  });

  describe("必要な速さの上限に当たった1日の目安があるとき", () => {
    let guideId: RecordId;
    beforeEach(async () => {
      guideId = generateRecordId();
      await seed(async (factory) => {
        await factory.dailyGuideLimitHits.create({
          dailyGuideId: (await factory.dailyGuides.create({ id: guideId })).id,
          limitType: "required_pace",
        });
        return [{ recordType: "daily_guide", recordId: guideId }];
      });
    });

    test("当たった上限と下限が、必要な速さの上限だけで届くこと", async () => {
      const [change] = await pullChanges();
      expect(change?.record["limitHits"]).toEqual(["required_pace"]);
    });
  });
});
