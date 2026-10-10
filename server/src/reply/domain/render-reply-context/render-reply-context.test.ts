import { beforeEach, describe, expect, test } from "vitest";
import { recordIdSchema } from "../../../domain/record-id";
import type { ReplyContext } from "../reply-context";
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
      sentAt: { at: "2026-10-10T13:00", dayOfWeek: "土" },
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
      yesterdayMeals: [],
      previousDays: [{ calendarDay: "2026-10-09", recorded: false }],
      weeklyWeightTrend: [{ firstDay: "2026-10-04", lastDay: "2026-10-10", trendKg: 72.45 }],
      lastWeightRecord: { at: "2026-10-10T07:50", weightKg: 72.4 },
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

    test("新しい発言に、送った時刻と本文を書くこと", () => {
      expect(blocks[2]?.text).toBe("10/10(土) 13:00 ユーザー: このあと何を食べたらいい？");
    });
  });
});
