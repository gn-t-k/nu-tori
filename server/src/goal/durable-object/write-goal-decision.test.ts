import { env, runInDurableObject } from "cloudflare:test";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { createRecordChangeWriter } from "../../durable-object/create-record-change-writer";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { regularSubscriptionAccount } from "../../durable-object/testing/regular-subscription-account";
import { writeGoalDecision } from "../domain/write-goal-decision";

type Decision = Parameters<typeof writeGoalDecision>[2];

type Written = {
  // 書く口が投げたエラーの文。投げなければ undefined
  errors: (string | undefined)[];
  rows: Record<string, unknown[]>;
  // 変更の並び。通し番号の順に、記録の種類だけ
  changedRecordTypes: unknown[];
  foreignKeyViolations: unknown[];
};

// 新しいアカウントの置き場に、決めたことを順に書き、書いたあとの行を返す。1つずつ、記録の変化を書く入口のトランザクションで書く
const writeInAccount = (decisions: Decision[]): Promise<Written> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_, state) => {
    const stores = createRecordKindStores(state.storage, regularSubscriptionAccount);
    const errors = decisions.map((decision) => {
      try {
        createRecordChangeWriter(state.storage)(({ addChange }) =>
          writeGoalDecision(stores, addChange, decision),
        );
        return undefined;
      } catch (thrown) {
        return thrown instanceof Error ? thrown.message : String(thrown);
      }
    });
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    return {
      errors,
      rows: {
        goals: read("SELECT started_on, target_weight_kg FROM goals ORDER BY decided_at"),
        weightChangeGoals: read("SELECT deadline_on, pace_plan FROM weight_change_goals"),
        currentGoals: read(
          "SELECT target_weight_kg FROM goals WHERE id NOT IN (SELECT goal_id FROM goal_closures)",
        ),
        closures: read("SELECT goal_id FROM goal_closures"),
        estimates: read("SELECT expenditure_kcal FROM expenditure_estimates"),
        initialEstimates: read("SELECT source FROM initial_expenditure_estimates"),
        dailyGuides: read("SELECT effective_on, energy_kcal FROM daily_guides ORDER BY rowid"),
        limitHits: read("SELECT limit_type FROM daily_guide_limit_hits ORDER BY limit_type"),
        receipts: read("SELECT id FROM goal_decision_receipts ORDER BY rowid"),
      },
      changedRecordTypes: read("SELECT record_type FROM record_changes ORDER BY sequence").map(
        (change) => change["record_type"],
      ),
      foreignKeyViolations: read("PRAGMA foreign_key_check"),
    };
  });

const createDecision = (overrides: {
  goal?: Partial<Decision["goal"]>;
  dailyGuide?: Partial<Decision["dailyGuide"]>;
  initialExpenditure: Decision["initialExpenditure"];
}): Decision => ({
  requestId: generateRecordId(),
  goal: {
    startedOn: "2026-10-01",
    startingWeightTrendKg: 70,
    targetWeightKg: 70,
    decidedAt: new Date("2026-10-01T03:00:00Z"),
    timeZone: "Asia/Tokyo",
    weightChange: undefined,
    ...overrides.goal,
  },
  dailyGuide: {
    energyKcal: 2400,
    proteinG: 110,
    fatG: 65,
    carbohydrateG: 345,
    limitHits: [],
    ...overrides.dailyGuide,
  },
  initialExpenditure: overrides.initialExpenditure,
});

const initialExpenditure = { expenditureKcal: 2400, source: "back_calculated" } as const;

describe("目標を決めたことを書く口", () => {
  describe("初めての、上限と下限に当たった減量の目標を書いたとき", () => {
    let written: Written;
    let decision: Decision;
    beforeEach(async () => {
      decision = createDecision({
        goal: {
          targetWeightKg: 65.5,
          weightChange: { deadlineOn: "2026-12-30", pacePlan: "standard" },
        },
        dailyGuide: { energyKcal: 1200, limitHits: ["required_pace", "minimum_energy"] },
        initialExpenditure,
      });
      written = await writeInAccount([decision]);
    });

    test("投げずに、外部キーの違反を残さないこと", () => {
      expect({ errors: written.errors, violations: written.foreignKeyViolations }).toEqual({
        errors: [undefined],
        violations: [],
      });
    });

    test("推定・推定の始まり・目標・減量の目標・開始の日から当てる1日の目安・当たった上限と下限・受け取りを書くこと", () => {
      expect(written.rows).toEqual({
        goals: [{ started_on: "2026-10-01", target_weight_kg: 65.5 }],
        weightChangeGoals: [{ deadline_on: "2026-12-30", pace_plan: "standard" }],
        currentGoals: [{ target_weight_kg: 65.5 }],
        closures: [],
        estimates: [{ expenditure_kcal: 2400 }],
        initialEstimates: [{ source: "back_calculated" }],
        dailyGuides: [{ effective_on: "2026-10-01", energy_kcal: 1200 }],
        limitHits: [{ limit_type: "minimum_energy" }, { limit_type: "required_pace" }],
        receipts: [{ id: decision.requestId }],
      });
    });

    test("目標、1日の目安、推定消費カロリーの順に変更を足すこと", () => {
      expect(written.changedRecordTypes).toEqual(["goal", "daily_guide", "expenditure_estimate"]);
    });
  });

  describe("初めての目標のあとに、2回立て直したとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        createDecision({ initialExpenditure }),
        createDecision({
          goal: {
            startedOn: "2026-10-08",
            targetWeightKg: 68,
            decidedAt: new Date("2026-10-08T03:00:00Z"),
            weightChange: { deadlineOn: "2026-12-30", pacePlan: "custom" },
          },
          initialExpenditure: undefined,
        }),
        // 同じ日の立て直し。開始の日は今の目標と同じでよい
        createDecision({
          goal: {
            startedOn: "2026-10-08",
            targetWeightKg: 72,
            decidedAt: new Date("2026-10-08T04:00:00Z"),
            weightChange: { deadlineOn: "2026-12-30", pacePlan: "gentle" },
          },
          initialExpenditure: undefined,
        }),
      ]);
    });

    test("投げずに、外部キーの違反を残さないこと", () => {
      expect({ errors: written.errors, violations: written.foreignKeyViolations }).toEqual({
        errors: [undefined, undefined, undefined],
        violations: [],
      });
    });

    test("閉じていない目標が、最後に決めた1つだけであること", () => {
      expect({
        goalCount: written.rows["goals"]?.length,
        closureCount: written.rows["closures"]?.length,
        currentGoals: written.rows["currentGoals"],
      }).toEqual({ goalCount: 3, closureCount: 2, currentGoals: [{ target_weight_kg: 72 }] });
    });

    test("推定と推定の始まりが、初めての1つだけであること", () => {
      expect({
        estimates: written.rows["estimates"],
        initialEstimates: written.rows["initialEstimates"],
      }).toEqual({
        estimates: [{ expenditure_kcal: 2400 }],
        initialEstimates: [{ source: "back_calculated" }],
      });
    });

    test("立て直すたびに、閉じた目標、新しい目標、1日の目安の順に変更を足すこと", () => {
      expect(written.changedRecordTypes).toEqual([
        "goal",
        "daily_guide",
        "expenditure_estimate",
        "goal",
        "goal",
        "daily_guide",
        "goal",
        "goal",
        "daily_guide",
      ]);
    });
  });

  describe("推定がもうあるのに、推定の始まりを渡したとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        createDecision({ initialExpenditure }),
        createDecision({ initialExpenditure: { expenditureKcal: 2000, source: "formula" } }),
      ]);
    });

    test("投げて、2つめの目標も推定も書かないこと", () => {
      expect({
        errors: written.errors,
        goalCount: written.rows["goals"]?.length,
        estimates: written.rows["estimates"],
        initialEstimates: written.rows["initialEstimates"],
        receiptCount: written.rows["receipts"]?.length,
      }).toEqual({
        errors: [undefined, "推定消費カロリーの推定がもうあるのに、推定の始まりを書こうとした"],
        goalCount: 1,
        estimates: [{ expenditure_kcal: 2400 }],
        initialEstimates: [{ source: "back_calculated" }],
        receiptCount: 1,
      });
    });
  });

  describe("推定が無いのに、推定の始まりを渡さなかったとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([createDecision({ initialExpenditure: undefined })]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, goals: written.rows["goals"] }).toEqual({
        errors: ["推定消費カロリーの推定が無いのに、推定の始まりを渡していない"],
        goals: [],
      });
    });
  });

  describe("今の目標の開始の日より前の日を、開始の日にして立て直したとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        createDecision({ initialExpenditure }),
        createDecision({ goal: { startedOn: "2026-09-30" }, initialExpenditure: undefined }),
      ]);
    });

    test("投げて、今の目標を閉じず、新しい目標を書かないこと", () => {
      expect({
        errors: written.errors,
        goals: written.rows["goals"],
        closures: written.rows["closures"],
      }).toEqual({
        errors: [undefined, "新しい目標の開始の日が、今の目標の開始の日より前"],
        goals: [{ started_on: "2026-10-01", target_weight_kg: 70 }],
        closures: [],
      });
    });
  });

  describe("目標体重が開始の日の体重の傾向と等しい、減量・増量の目標を書いたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount([
        createDecision({
          goal: { weightChange: { deadlineOn: "2026-12-30", pacePlan: "standard" } },
          initialExpenditure,
        }),
      ]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, goals: written.rows["goals"] }).toEqual({
        errors: ["減量・増量の目標の目標体重が、開始の日の体重の傾向と等しい"],
        goals: [],
      });
    });
  });

  describe("一覧に無い速さの案を書いたとき", () => {
    let written: Written;
    beforeEach(async () => {
      const decision = createDecision({ goal: { targetWeightKg: 65 }, initialExpenditure });
      // 型をすり抜けた値（古い版のコードや、別の経路から来た値）を作る
      Object.assign(decision.goal, {
        weightChange: { deadlineOn: "2026-12-30", pacePlan: "fastest" },
      });
      written = await writeInAccount([decision]);
    });

    test("投げて、何も書かないこと", () => {
      expect({ errors: written.errors, goals: written.rows["goals"] }).toEqual({
        errors: ["速さの案の値が一覧に無い"],
        goals: [],
      });
    });
  });
});
