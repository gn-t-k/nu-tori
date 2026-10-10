import { beforeEach, describe, expect, test } from "vitest";
import type { ClassificationEvalOutput } from "../classification-eval-output";
import { judgeClassificationError } from "./index";

describe("読み分けの間違いを1件ずつ数える", () => {
  describe("Jev の確からしさのとき", () => {
    describe("正解が食事で、確からしさがしきい値ちょうどのとき", () => {
      let output: ClassificationEvalOutput;
      beforeEach(() => {
        output = { kind: "probability", mealProbability: 0.7 };
      });

      test("食事と読んだとして、食事を会話にした間違いに数えないこと", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "meal" },
            config: { threshold: 0.7, error: "meal_as_chat" },
          }).score,
        ).toBe(0);
      });
    });

    describe("正解が食事で、確からしさがしきい値を下回るとき", () => {
      let output: ClassificationEvalOutput;
      beforeEach(() => {
        output = { kind: "probability", mealProbability: 0.69 };
      });

      test("会話と読んだとして、食事を会話にした間違いに数えること", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "meal" },
            config: { threshold: 0.7, error: "meal_as_chat" },
          }).score,
        ).toBe(1);
      });

      test("会話を食事にした間違いには数えないこと", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "meal" },
            config: { threshold: 0.7, error: "chat_as_meal" },
          }).score,
        ).toBe(0);
      });
    });

    describe("正解が会話で、確からしさがしきい値以上のとき", () => {
      let output: ClassificationEvalOutput;
      beforeEach(() => {
        output = { kind: "probability", mealProbability: 0.9 };
      });

      test("会話を食事にした間違いに数えること", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "chat" },
            config: { threshold: 0.7, error: "chat_as_meal" },
          }).score,
        ).toBe(1);
      });
    });
  });

  describe("Haiku 5.5 の答えのとき", () => {
    describe("正解が食事で、決めかねると答えたとき", () => {
      let output: ClassificationEvalOutput;
      beforeEach(() => {
        output = { kind: "label", label: "unsure" };
      });

      test("会話として、食事を会話にした間違いに数えること", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "meal" },
            config: { threshold: 0.5, error: "meal_as_chat" },
          }).score,
        ).toBe(1);
      });
    });

    describe("正解が会話で、食事と答えたとき", () => {
      let output: ClassificationEvalOutput;
      beforeEach(() => {
        output = { kind: "label", label: "meal" };
      });

      test("しきい値に関わらず、会話を食事にした間違いに数えること", () => {
        expect(
          judgeClassificationError(output, {
            vars: { expected: "chat" },
            config: { threshold: 0.95, error: "chat_as_meal" },
          }).score,
        ).toBe(1);
      });
    });
  });

  describe("間違いのとき", () => {
    let output: ClassificationEvalOutput;
    beforeEach(() => {
      output = { kind: "probability", mealProbability: 0.1 };
    });

    test("テストを落とさず、件数を score だけで数えること", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "meal" },
          config: { threshold: 0.5, error: "meal_as_chat" },
        }).pass,
      ).toBe(true);
    });
  });
});
