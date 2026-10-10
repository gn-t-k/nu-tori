import { beforeEach, describe, expect, test } from "vitest";
import { readClassificationResults } from "./index";

// 結果の JSON の形は、promptfoo 0.124.1 で偽の提供元を回して確かめたもの（-o の results.prompts[].metrics）
describe("promptfoo の結果から、しきい値ごとの間違いの数を読む", () => {
  describe("両方のモデルが全件に答えたとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          prompts: [
            {
              provider: "jev",
              metrics: {
                testErrorCount: 0,
                namedScores: {
                  meal_as_chat_050: 0,
                  chat_as_meal_050: 3,
                  meal_as_chat_055: 1,
                  chat_as_meal_055: 2,
                  meal_as_chat_060: 1,
                  chat_as_meal_060: 2,
                  meal_as_chat_065: 2,
                  chat_as_meal_065: 1,
                  meal_as_chat_070: 2,
                  chat_as_meal_070: 1,
                  meal_as_chat_075: 3,
                  chat_as_meal_075: 0,
                  meal_as_chat_080: 4,
                  chat_as_meal_080: 0,
                  meal_as_chat_085: 4,
                  chat_as_meal_085: 0,
                  meal_as_chat_090: 6,
                  chat_as_meal_090: 0,
                  meal_as_chat_095: 9,
                  chat_as_meal_095: 0,
                },
              },
            },
            {
              provider: "haiku",
              metrics: {
                testErrorCount: 0,
                namedScores: {
                  meal_as_chat_050: 2,
                  chat_as_meal_050: 1,
                  meal_as_chat_095: 2,
                  chat_as_meal_095: 1,
                },
              },
            },
          ],
        },
      };
    });

    test("Jev のしきい値ごとの2種類の数と、Haiku 5.5 の2種類の数を返すこと", () => {
      expect(readClassificationResults(results)).toEqual({
        status: "complete",
        haiku: { mealAsChat: 2, chatAsMeal: 1 },
        jev: [
          { threshold: 0.5, mealAsChat: 0, chatAsMeal: 3 },
          { threshold: 0.55, mealAsChat: 1, chatAsMeal: 2 },
          { threshold: 0.6, mealAsChat: 1, chatAsMeal: 2 },
          { threshold: 0.65, mealAsChat: 2, chatAsMeal: 1 },
          { threshold: 0.7, mealAsChat: 2, chatAsMeal: 1 },
          { threshold: 0.75, mealAsChat: 3, chatAsMeal: 0 },
          { threshold: 0.8, mealAsChat: 4, chatAsMeal: 0 },
          { threshold: 0.85, mealAsChat: 4, chatAsMeal: 0 },
          { threshold: 0.9, mealAsChat: 6, chatAsMeal: 0 },
          { threshold: 0.95, mealAsChat: 9, chatAsMeal: 0 },
        ],
      });
    });
  });

  describe("呼び出しに失敗した件があるとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          prompts: [
            { provider: "jev", metrics: { testErrorCount: 3, namedScores: {} } },
            { provider: "haiku", metrics: { testErrorCount: 0, namedScores: {} } },
          ],
        },
      };
    });

    test("数えずに、モデルごとの失敗の数を返すこと", () => {
      expect(readClassificationResults(results)).toEqual({
        status: "incomplete",
        errorCounts: { jev: 3, haiku: 0 },
      });
    });
  });
});
