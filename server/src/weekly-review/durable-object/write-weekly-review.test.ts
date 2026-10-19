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
  // 変更の並び。通し番号の順に
  changes: unknown[];
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
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    // 目標を決めた分の変更は比べない
    const decisionChangeCount = read("SELECT sequence FROM record_changes").length;
    const errors = reviews.map((review) => {
      try {
        writeRecordChanges(({ addChange }) => writeWeeklyReview(stores, addChange, review(goalId)));
        return undefined;
      } catch (thrown) {
        return thrown instanceof Error ? thrown.message : String(thrown);
      }
    });
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
        reviewedExpenditureEstimates: read(
          "SELECT e.effective_on, e.expenditure_kcal, e.estimated_at, r.deviation_direction, w.effective_on AS review_effective_on FROM reviewed_expenditure_estimates r JOIN expenditure_estimates e ON e.id = r.expenditure_estimate_id JOIN weekly_reviews w ON w.id = r.weekly_review_id ORDER BY e.effective_on",
        ),
        reviewedDailyGuides: read(
          "SELECT g.goal_id, g.effective_on, g.energy_kcal, g.protein_g, g.fat_g, g.carbohydrate_g, e.effective_on AS estimate_effective_on, r.main_reason FROM reviewed_daily_guides r JOIN daily_guides g ON g.id = r.daily_guide_id JOIN expenditure_estimates e ON e.id = g.expenditure_estimate_id ORDER BY g.effective_on",
        ),
        limitHits: read(
          "SELECT g.effective_on, h.limit_type FROM daily_guide_limit_hits h JOIN daily_guides g ON g.id = h.daily_guide_id ORDER BY g.effective_on, h.limit_type",
        ),
      },
      changes: read(
        `SELECT record_type FROM record_changes ORDER BY sequence LIMIT -1 OFFSET ${decisionChangeCount}`,
      ),
      foreignKeyViolations: read("PRAGMA foreign_key_check"),
    };
  });

const deferral =
  (
    overrides: {
      effectiveOn?: string;
      goalId?: RecordId;
      reason?: "no_weight" | "few_meal_records" | "within_first_week";
    } = {},
  ) =>
  (goalId: RecordId): Review => ({
    effectiveOn: overrides.effectiveOn ?? "2026-10-12",
    reviewedAt: new Date("2026-10-19T00:30:00Z"),
    timeZone: "Asia/Tokyo",
    outcome: {
      type: "deferred",
      reason: overrides.reason ?? "no_weight",
      goalId: overrides.goalId ?? goalId,
    },
  });

const review =
  (overrides: { effectiveOn?: string; goalId?: RecordId } = {}) =>
  (goalId: RecordId): Review => ({
    effectiveOn: overrides.effectiveOn ?? "2026-10-12",
    reviewedAt: new Date("2026-10-19T00:30:00Z"),
    timeZone: "Asia/Tokyo",
    outcome: {
      type: "reviewed",
      expenditure: { expenditureKcal: 2600, deviationDirection: "positive" },
      dailyGuide: {
        goalId: overrides.goalId ?? goalId,
        energyKcal: 2550,
        proteinG: 110,
        fatG: 70,
        carbohydrateG: 370,
        limitHits: ["weekly_change"],
        mainReason: "expenditure_change",
      },
    },
  });

const emptyRows = {
  weeklyReviews: [],
  deferredWeeklyReviews: [],
  reviewedExpenditureEstimates: [],
  reviewedDailyGuides: [],
  limitHits: [],
};

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
        ...emptyRows,
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
      expect(written.changes).toEqual([
        { record_type: "weekly_review" },
        { record_type: "weekly_review" },
      ]);
    });
  });

  describe("今の目標に、見直せた週を書いたとき", () => {
    let written: Written & { goalId: RecordId };
    beforeEach(async () => {
      written = await writeInAccount([review()]);
    });

    test("投げずに、外部キーの違反を残さないこと", () => {
      expect({ errors: written.errors, violations: written.foreignKeyViolations }).toEqual({
        errors: [undefined],
        violations: [],
      });
    });

    test("週の見直しと同じ月曜と時刻の推定と、その推定を指す今の目標の1日の目安を書くこと", () => {
      expect(written.rows).toEqual({
        ...emptyRows,
        weeklyReviews: [
          {
            effective_on: "2026-10-12",
            reviewed_at: Date.parse("2026-10-19T00:30:00Z"),
            time_zone: "Asia/Tokyo",
          },
        ],
        reviewedExpenditureEstimates: [
          {
            effective_on: "2026-10-12",
            expenditure_kcal: 2600,
            estimated_at: Date.parse("2026-10-19T00:30:00Z"),
            deviation_direction: "positive",
            review_effective_on: "2026-10-12",
          },
        ],
        reviewedDailyGuides: [
          {
            goal_id: written.goalId,
            effective_on: "2026-10-12",
            energy_kcal: 2550,
            protein_g: 110,
            fat_g: 70,
            carbohydrate_g: 370,
            estimate_effective_on: "2026-10-12",
            main_reason: "expenditure_change",
          },
        ],
        limitHits: [{ effective_on: "2026-10-12", limit_type: "weekly_change" }],
      });
    });

    test("推定消費カロリー、1日の目安、週の見直しの順に変更を足すこと", () => {
      expect(written.changes).toEqual([
        { record_type: "expenditure_estimate" },
        { record_type: "daily_guide" },
        { record_type: "weekly_review" },
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
        errors: ["見直しの目標が、今の目標ではない"],
        rows: emptyRows,
      });
    });
  });

  describe("今の目標でない目標の1日の目安を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([review({ goalId: generateRecordId() })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見直しの目標が、今の目標ではない"],
        rows: emptyRows,
      });
    });
  });

  describe("最も遅い推定の当てる始まりの日より後でない月曜を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([review({ effectiveOn: "2026-10-05" })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見直す月曜が、最も遅い推定の当てる始まりの日より後でない"],
        rows: emptyRows,
      });
    });
  });

  describe("見直せた週のあとに、同じ月曜の見送りを書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([review(), deferral()]);
    });

    test("2つめを、見直した推定より後でない月曜として投げること", () => {
      expect(written.errors).toEqual([
        undefined,
        "見直す月曜が、最も遅い推定の当てる始まりの日より後でない",
      ]);
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
        rows: emptyRows,
      });
    });
  });

  describe("一覧に無い見送りの理由を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      // 型をすり抜けた値（古い版のコードや、別の経路から来た値）を作る
      written = await writeInAccount([
        (goalId) => {
          const invalid = deferral()(goalId);
          Object.assign(invalid.outcome, { reason: "too_busy" });
          return invalid;
        },
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["見送りの理由の値が一覧に無い"],
        rows: emptyRows,
      });
    });
  });

  describe("一覧に無いずれの向きを書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        (goalId) => {
          const invalid = review()(goalId);
          if (invalid.outcome.type === "reviewed") {
            Object.assign(invalid.outcome.expenditure, { deviationDirection: "sideways" });
          }
          return invalid;
        },
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["ずれの向きの値が一覧に無い"],
        rows: emptyRows,
      });
    });
  });

  describe("一覧に無い主な理由を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        (goalId) => {
          const invalid = review()(goalId);
          if (invalid.outcome.type === "reviewed") {
            Object.assign(invalid.outcome.dailyGuide, { mainReason: "weather" });
          }
          return invalid;
        },
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["主な理由の値が一覧に無い"],
        rows: emptyRows,
      });
    });
  });

  describe("一覧に無い上限と下限を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        (goalId) => {
          const invalid = review()(goalId);
          if (invalid.outcome.type === "reviewed") {
            Object.assign(invalid.outcome.dailyGuide, { limitHits: ["daily_change"] });
          }
          return invalid;
        },
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, rows: written.rows }).toEqual({
        errors: ["当たった上限と下限の値が一覧に無い"],
        rows: emptyRows,
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
