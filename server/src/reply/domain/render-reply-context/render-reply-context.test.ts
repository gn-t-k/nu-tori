import { beforeEach, describe, expect, test } from "vitest";
import { recordIdSchema } from "../../../domain/record-id";
import type { Pace } from "../../../goal/domain/compute-pace";
import type { ReplyContext, ReplyContextWeeklyReview } from "../reply-context";
import { type ReplyContextBlock, renderReplyContext } from "./index";

describe("返事に渡す文脈の文", () => {
  const mealId = recordIdSchema.parse("00000000-0000-4000-8000-000000000004");
  const context: ReplyContext = {
    window: [
      { type: "user_utterance", at: "2026-10-10T07:00", body: "朝ごはん何がいい？" },
      { type: "ai_utterance", at: "2026-10-10T07:00", body: "たんぱく質を足しましょう" },
      { type: "weight_recorded", at: "2026-10-10T07:50", weightKg: 72.4 },
      {
        type: "meal_recorded",
        at: "2026-10-10T12:40",
        mealId,
        eatenAt: "2026-10-10T12:30",
        dishNames: ["親子丼", "味噌汁"],
      },
    ],
    structuredValues: {
      sentAt: { at: "2026-10-10T13:00", dayOfWeek: "saturday" },
      todayMeals: [
        {
          mealId,
          eatenAt: "2026-10-10T12:30",
          estimation: "settled",
          dishes: [
            {
              name: "親子丼",
              quantity: { value: 1, unit: "杯" },
              nutrients: {
                energyKcal: { type: "exactly", value: 650.4 },
                proteinG: { type: "exactly", value: 30.26 },
                fatG: { type: "at_least", value: 18 },
                carbohydrateG: { type: "unknown" },
              },
            },
          ],
        },
      ],
      todayNutrients: {
        energyKcal: { type: "exactly", value: 650.4 },
        proteinG: { type: "exactly", value: 30.26 },
        fatG: { type: "at_least", value: 18 },
        carbohydrateG: { type: "unknown" },
      },
      yesterdayMeals: [],
      previousDays: [{ calendarDay: "2026-10-09", recorded: false }],
      weeklyWeightTrend: [{ firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: 72.45 }],
      lastWeightRecord: { at: "2026-10-10T07:50", weightKg: 72.4 },
      goal: undefined,
    },
    newUtterance: { at: "2026-10-10T13:00", body: "このあと何を食べたらいい？" },
  };

  describe("窓に発言と記録の印があるとき", () => {
    let blocks: readonly ReplyContextBlock[];
    beforeEach(() => {
      blocks = renderReplyContext(context);
    });

    test("文脈の窓、構造化した値、新しい発言の順に並べること", () => {
      expect(blocks.map(({ kind }) => kind)).toEqual([
        "window",
        "structured_values",
        "new_utterance",
      ]);
    });

    test("記録の印を、時刻と料理の名前と食事の ID の1行にすること", () => {
      expect(blocks[0]?.text).toContain(
        "10/10(土) 12:40 食事を記録（親子丼、味噌汁。食事 ID: 00000000-0000-4000-8000-000000000004）",
      );
    });

    test("料理ごとの栄養を、以上と不明を書き分けて丸めること", () => {
      expect(blocks[1]?.text).toContain("親子丼（1 杯）: 650 kcal、P 30.3 g、F 18 g 以上、C 不明");
    });

    test("今日の食事の合計を1行にすること", () => {
      expect(blocks[1]?.text).toContain("今日の合計: 650 kcal、P 30.3 g、F 18 g 以上、C 不明");
    });

    test("新しい発言に、送った時刻と本文を書くこと", () => {
      expect(blocks[2]?.text).toBe("10/10(土) 13:00 ユーザー: このあと何を食べたらいい？");
    });

    test("目標が無いとき、目標の節を書かないこと", () => {
      expect(blocks[1]?.text).not.toContain("目標");
    });
  });

  describe("減量の目標があるとき", () => {
    let text: string | undefined;
    beforeEach(() => {
      text = renderReplyContext({
        ...context,
        structuredValues: {
          ...context.structuredValues,
          goal: {
            direction: "lose",
            deadlineOn: "2027-02-01",
            targetWeightKg: 68.45,
            dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
            expenditureKcal: 2350,
            latestWeeklyReview: undefined,
            pace: undefined,
          },
        },
      })[1]?.text;
    });

    test("目標の向き・期限・目標体重と、今日の1日の目安と推定消費カロリーを書くこと", () => {
      expect(text).toContain(
        [
          "## 目標",
          "減量。期限 2027/02/01(月)、目標体重 68.5 kg",
          "今日の1日の目安: 2000 kcal、P 105 g、F 55 g、C 270 g",
          "推定消費カロリー: 2350 kcal",
        ].join("\n"),
      );
    });
  });

  describe("維持の目標で、1日の目安と推定消費カロリーが無いとき", () => {
    let text: string | undefined;
    beforeEach(() => {
      text = renderReplyContext({
        ...context,
        structuredValues: {
          ...context.structuredValues,
          goal: {
            direction: "maintain",
            deadlineOn: undefined,
            targetWeightKg: 72,
            dailyGuide: undefined,
            expenditureKcal: undefined,
            latestWeeklyReview: undefined,
            pace: undefined,
          },
        },
      })[1]?.text;
    });

    test("期限を書かず、1日の目安と推定消費カロリーをなしと書くこと", () => {
      expect(text).toContain(
        ["## 目標", "維持。目標体重 72 kg", "今日の1日の目安: なし", "推定消費カロリー: なし"].join(
          "\n",
        ),
      );
    });
  });

  const renderWithReview = (latestWeeklyReview: ReplyContextWeeklyReview) =>
    renderReplyContext({
      ...context,
      structuredValues: {
        ...context.structuredValues,
        goal: {
          direction: "lose",
          deadlineOn: "2027-02-01",
          targetWeightKg: 68.5,
          dailyGuide: { energyKcal: 1850, proteinG: 105, fatG: 55, carbohydrateG: 270 },
          expenditureKcal: 2330,
          latestWeeklyReview,
          pace: undefined,
        },
      },
    })[1]?.text;

  describe("目標に直近の週の見直しがあるとき", () => {
    test("見直せた週は、月曜と、前の週からの変化と、主な理由と、当たった上限と下限を書くこと", () => {
      expect(
        renderWithReview({
          type: "reviewed",
          effectiveOn: "2026-10-05",
          limitHits: ["weekly_change", "minimum_energy"],
          mainReason: "balance_change",
          dailyGuideChangeKcal: -150,
          expenditureChangeKcal: 20,
        }),
      ).toContain(
        [
          "直近の週の見直し: 10/05(月)から。前の週から1日の目安 -150 kcal、推定消費カロリー +20 kcal",
          "  主な理由: 1日に減らす（足す）分の変化",
          "  当たった上限と下限: 前の週からの変化の上限（±150 kcal）、1日の目安の下限",
        ].join("\n"),
      );
    });

    test("上限にも下限にも当たらなかった週は、なしと書くこと", () => {
      expect(
        renderWithReview({
          type: "reviewed",
          effectiveOn: "2026-10-05",
          limitHits: [],
          mainReason: "expenditure_change",
          dailyGuideChangeKcal: 0,
          expenditureChangeKcal: 0,
        }),
      ).toContain(
        [
          "直近の週の見直し: 10/05(月)から。前の週から1日の目安 ±0 kcal、推定消費カロリー ±0 kcal",
          "  主な理由: 推定消費カロリーの変化",
          "  当たった上限と下限: なし",
        ].join("\n"),
      );
    });

    test("見送った週は、月曜と理由と、前の週のままであることを書くこと", () => {
      expect(
        renderWithReview({
          type: "deferred",
          effectiveOn: "2026-10-12",
          reason: "few_meal_records",
        }),
      ).toContain(
        "直近の週の見直し: 10/12(月)から。見送った（食事の記録が少ない）。1日の目安と推定消費カロリーは前の週のまま",
      );
    });
  });

  describe("目標にその日のペースがあるとき", () => {
    test.for<[string, Pace | undefined, string]>([
      [
        "間に合う",
        { status: "onTrack", actualKgPerWeek: -0.5, requiredKgPerWeek: -0.3 },
        "ペース: 今の体重の傾向の動きのままなら、期限に目標体重へ届く",
      ],
      [
        "届かない",
        { status: "behind", shortfallKg: 1.2, actualKgPerWeek: -0.1, requiredKgPerWeek: -0.3 },
        "ペース: 今の体重の傾向の動きのままだと、期限に目標体重まで 1.2 kg 届かない",
      ],
      [
        "言い切らない",
        { status: "inconclusive", weightRecordDayCount: 2 },
        "ペース: 言い切れない（直近 14 日に体重を記録した日が 2 日しかない）",
      ],
      ["まだ出ない", { status: "pending" }, "ペース: まだ出ない（目標を立てて 14 日たっていない）"],
      ["返さない", { status: "unavailable" }, "ペース: なし（期限の日か達成した日を迎えた）"],
      [
        "維持の幅に収まる",
        { status: "maintenance", isWithinBand: true },
        "ペース: 体重の傾向が目標体重の ±0.7 kg に収まっている",
      ],
      [
        "維持の幅を外れる",
        { status: "maintenance", isWithinBand: false },
        "ペース: 体重の傾向が目標体重の ±0.7 kg を外れている",
      ],
      ["出せない", undefined, "ペース: なし"],
    ])("%s とき、そのことを1行で書くこと", ([, pace, line]) => {
      expect(
        renderReplyContext({
          ...context,
          structuredValues: {
            ...context.structuredValues,
            goal: {
              direction: "lose",
              deadlineOn: "2027-02-01",
              targetWeightKg: 68.5,
              dailyGuide: undefined,
              expenditureKcal: undefined,
              latestWeeklyReview: undefined,
              pace,
            },
          },
        })[1]?.text.split("\n"),
      ).toContain(line);
    });
  });
});
