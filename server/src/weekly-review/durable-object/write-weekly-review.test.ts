import { env, runInDurableObject } from "cloudflare:test";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { createRecordChangeWriter } from "../../durable-object/create-record-change-writer";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { writeGoalDecision } from "../../goal/domain/write-goal-decision";
import { writeWeeklyReview } from "../domain/write-weekly-review";

type Review = Parameters<typeof writeWeeklyReview>[2];

type Written = {
  // 書く口が投げたエラーの文。投げなければ undefined
  errors: (string | undefined)[];
  rows: Record<string, unknown[]>;
  // 変更の並びのうち、週の見直しのもの。通し番号の順に
  changedReviews: unknown[];
  foreignKeyViolations: unknown[];
};

// 新しいアカウントに、2026-10-07（水）に立てた初めての目標を置き、置いた目標の ID から作った週の見直しを順に書く
const writeInAccount = (
  reviews: ((goalId: RecordId) => Review)[],
): Promise<Written & { goalId: RecordId }> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_, state) => {
    const stores = createRecordKindStores(state.storage);
    const writeRecordChanges = createRecordChangeWriter(state.storage);
    const goalId = writeRecordChanges(({ addChange }) =>
      writeGoalDecision(stores, addChange, {
        requestId: generateRecordId(),
        goal: {
          startedOn: "2026-10-07",
          startingWeightTrendKg: 70,
          targetWeightKg: 70,
          decidedAt: new Date("2026-10-07T03:00:00Z"),
          timeZone: "Asia/Tokyo",
          weightChange: undefined,
        },
        dailyGuide: {
          energyKcal: 2400,
          proteinG: 110,
          fatG: 65,
          carbohydrateG: 345,
          limitHits: [],
        },
        initialExpenditure: { expenditureKcal: 2400, source: "formula" },
      }),
    );
    const errors = reviews.map((review) => {
      try {
        writeRecordChanges(({ addChange }) => writeWeeklyReview(stores, addChange, review(goalId)));
        return undefined;
      } catch (thrown) {
        return thrown instanceof Error ? thrown.message : String(thrown);
      }
    });
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    return {
      goalId,
      errors,
      rows: {
        weeklyReviews: read(
          "SELECT effective_on, reviewed_at, time_zone FROM weekly_reviews ORDER BY effective_on",
        ),
        deferredWeeklyReviews: read(
          "SELECT d.goal_id, d.reason FROM deferred_weekly_reviews d JOIN weekly_reviews w ON w.id = d.weekly_review_id ORDER BY w.effective_on",
        ),
      },
      changedReviews: read(
        "SELECT w.effective_on FROM record_changes c JOIN weekly_reviews w ON w.id = c.record_id WHERE c.record_type = 'weekly_review' ORDER BY c.sequence",
      ),
      foreignKeyViolations: read("PRAGMA foreign_key_check"),
    };
  });

const deferral =
  (overrides: { effectiveOn?: string; goalId?: RecordId } & Partial<Review["deferral"]> = {}) =>
  (goalId: RecordId): Review => ({
    effectiveOn: overrides.effectiveOn ?? "2026-10-12",
    reviewedAt: new Date("2026-10-19T00:30:00Z"),
    timeZone: "Asia/Tokyo",
    deferral: { reason: overrides.reason ?? "no_weight", goalId: overrides.goalId ?? goalId },
  });

describe("週の見直しを書く口", () => {
  describe("今の目標に、2つの週の見送りを古い順に書いたとき", () => {
    let written: Written & { goalId: RecordId };
    beforeEach(async () => {
      written = await writeInAccount([
        deferral({ effectiveOn: "2026-10-12", reason: "within_first_week" }),
        deferral({ effectiveOn: "2026-10-19", reason: "few_meal_records" }),
      ]);
    });

    test("投げずに、外部キーの違反を残さないこと", () => {
      expect({ errors: written.errors, violations: written.foreignKeyViolations }).toEqual({
        errors: [undefined, undefined],
        violations: [],
      });
    });

    test("週の見直しと、今の目標を指す見送りを1週に1組書くこと", () => {
      expect(written.rows).toEqual({
        weeklyReviews: [
          {
            effective_on: "2026-10-12",
            reviewed_at: Date.parse("2026-10-19T00:30:00Z"),
            time_zone: "Asia/Tokyo",
          },
          {
            effective_on: "2026-10-19",
            reviewed_at: Date.parse("2026-10-19T00:30:00Z"),
            time_zone: "Asia/Tokyo",
          },
        ],
        deferredWeeklyReviews: [
          { goal_id: written.goalId, reason: "within_first_week" },
          { goal_id: written.goalId, reason: "few_meal_records" },
        ],
      });
    });

    test("書いた順に、週の見直しの変更を足すこと", () => {
      expect(written.changedReviews).toEqual([
        { effective_on: "2026-10-12" },
        { effective_on: "2026-10-19" },
      ]);
    });
  });

  describe("今の目標でない目標を指す見送りを書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([deferral({ goalId: generateRecordId() })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見送りの目標が、今の目標ではない"],
        rows: { weeklyReviews: [], deferredWeeklyReviews: [] },
      });
    });
  });

  describe("最も遅い推定の当てる始まりの日より後でない月曜を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([deferral({ effectiveOn: "2026-10-05" })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見直す月曜が、最も遅い推定の当てる始まりの日より後でない"],
        rows: { weeklyReviews: [], deferredWeeklyReviews: [] },
      });
    });
  });

  describe("月曜でない日を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([deferral({ effectiveOn: "2026-10-13" })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見直しの当てる日が月曜でない"],
        rows: { weeklyReviews: [], deferredWeeklyReviews: [] },
      });
    });
  });

  describe("一覧に無い見送りの理由を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      // 型をすり抜けた値（古い版のコードや、別の経路から来た値）を作る
      written = await writeInAccount([
        (goalId) => {
          const review = deferral()(goalId);
          Object.assign(review.deferral, { reason: "too_busy" });
          return review;
        },
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見送りの理由の値が一覧に無い"],
        rows: { weeklyReviews: [], deferredWeeklyReviews: [] },
      });
    });
  });

  describe("見直した月曜をもう一度書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([deferral(), deferral()]);
    });

    test("2つめを書かないこと", () => {
      expect({
        firstError: written.errors[0],
        secondErrorCount: written.errors[1] === undefined ? 0 : 1,
        reviewCount: written.rows["weeklyReviews"]?.length,
      }).toEqual({ firstError: undefined, secondErrorCount: 1, reviewCount: 1 });
    });
  });
});
