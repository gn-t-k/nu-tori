import { beforeEach, describe, expect, test } from "vitest";
import { readClassificationResults } from "./index";

// 結果の JSON の形は、promptfoo 0.124.1 で偽の提供元を回して確かめたもの（-o の results.prompts[].metrics）
describe("promptfoo の結果から、間違いの数を読む", () => {
  describe("全件に答えたとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          prompts: [
            {
              provider: "haiku",
              metrics: {
                testErrorCount: 0,
                namedScores: { meal_as_chat: 2, chat_as_meal: 1 },
              },
            },
          ],
        },
      };
    });

    test("2種類の間違いの数を返すこと", () => {
      expect(readClassificationResults(results)).toEqual({
        status: "complete",
        mealAsChat: 2,
        chatAsMeal: 1,
      });
    });
  });

  describe("呼び出しに失敗した件があるとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          prompts: [{ provider: "haiku", metrics: { testErrorCount: 3, namedScores: {} } }],
        },
      };
    });

    test("数えずに、失敗の数を返すこと", () => {
      expect(readClassificationResults(results)).toEqual({
        status: "incomplete",
        errorCount: 3,
      });
    });
  });
});
