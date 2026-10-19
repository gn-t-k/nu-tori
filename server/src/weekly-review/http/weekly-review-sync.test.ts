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

// 週の見直しはサーバーだけが書く。記録の形を確かめるので、表に行を置き、記録の変化を書く入口で変更を足す
describe("週の見直しの同期", () => {
  let seed: (rows: (factory: Factory) => Promise<Change[]>) => Promise<void>;
  let pullChanges: () => Promise<Omit<PullResult["changes"][number], "sequence">[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    const signedIn = await signInTestAccount(generateRecordId());
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
      (await (await pullSyncChanges(signedIn.sessionToken)).json<PullResult>()).changes.map(
        ({ kind, recordId, record }) => ({ kind, recordId, record }),
      );
  });

  describe("体重が無くて見送った週があるとき", () => {
    let reviewId: RecordId;
    let goalId: RecordId;
    beforeEach(async () => {
      reviewId = generateRecordId();
      goalId = generateRecordId();
      await seed(async (factory) => {
        await factory.goals.create({ id: goalId });
        await factory.weeklyReviews.create({
          id: reviewId,
          effectiveOn: "2026-10-19",
          reviewedAt: new Date("2026-10-19T22:00:00Z"),
          timeZone: "America/Los_Angeles",
        });
        await factory.deferredWeeklyReviews.create({
          weeklyReviewId: reviewId,
          goalId,
          reason: "no_weight",
        });
        return [{ recordType: "weekly_review", recordId: reviewId }];
      });
    });

    test("当てる月曜・見直した時刻・タイムゾーンと、理由と目標の ID の見送りを持ち、見直しを持たない週の見直しが届くこと", async () => {
      expect(await pullChanges()).toEqual([
        {
          kind: "weekly_review",
          recordId: reviewId,
          record: {
            id: reviewId,
            effectiveOn: "2026-10-19",
            reviewedAt: Date.parse("2026-10-19T22:00:00Z"),
            timeZone: "America/Los_Angeles",
            deferral: { reason: "no_weight", goalId },
          },
        },
      ]);
    });
  });

  describe("推定消費カロリーの変化が主な理由で見直せた週があり、同じ推定を指す見直していない1日の目安もあるとき", () => {
    let reviewId: RecordId;
    let estimateId: RecordId;
    let reviewedGuideId: RecordId;
    beforeEach(async () => {
      reviewId = generateRecordId();
      estimateId = generateRecordId();
      reviewedGuideId = generateRecordId();
      await seed(async (factory) => {
        await factory.weeklyReviews.create({
          id: reviewId,
          effectiveOn: "2026-10-12",
          reviewedAt: new Date("2026-10-12T00:30:00Z"),
          timeZone: "Asia/Tokyo",
        });
        await factory.expenditureEstimates.create({
          id: estimateId,
          effectiveOn: "2026-10-12",
          estimatedAt: new Date("2026-10-12T00:30:00Z"),
        });
        await factory.reviewedExpenditureEstimates.create({
          expenditureEstimateId: estimateId,
          weeklyReviewId: reviewId,
          deviationDirection: "negative",
        });
        // 見送った週に期限後の維持へ移ると、前の推定を指す1日の目安が書かれる。これは見直した1日の目安ではない
        await factory.dailyGuides.create({ expenditureEstimateId: estimateId });
        await factory.dailyGuides.create({
          id: reviewedGuideId,
          expenditureEstimateId: estimateId,
          effectiveOn: "2026-10-12",
        });
        await factory.reviewedDailyGuides.create({
          dailyGuideId: reviewedGuideId,
          mainReason: "expenditure_change",
        });
        return [{ recordType: "weekly_review", recordId: reviewId }];
      });
    });

    test("見直した推定と見直した1日の目安の ID と主な理由の見直しを持ち、見送りもずれの向きも持たない週の見直しが届くこと", async () => {
      expect(await pullChanges()).toEqual([
        {
          kind: "weekly_review",
          recordId: reviewId,
          record: {
            id: reviewId,
            effectiveOn: "2026-10-12",
            reviewedAt: Date.parse("2026-10-12T00:30:00Z"),
            timeZone: "Asia/Tokyo",
            review: {
              expenditureEstimateId: estimateId,
              dailyGuideId: reviewedGuideId,
              mainReason: "expenditure_change",
            },
          },
        },
      ]);
    });
  });
});
