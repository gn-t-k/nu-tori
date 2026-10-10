import { beforeEach, describe, expect, test } from "vitest";
import { decideClassificationModel } from "./index";

// 決め方は #419 の「読み分け」と #423 の受け入れ条件。Haiku 5.5 の数＋4 は評価の組（80 個）の 5%
describe("読み分けのモデルを決める", () => {
  describe("会話を食事にした間違いが 0 で、食事を会話にした間違いが Haiku 5.5 の数＋4 以内のしきい値が2つ以上あるとき", () => {
    let input: Parameters<typeof decideClassificationModel>[0];
    beforeEach(() => {
      input = {
        haiku: { mealAsChat: 2, chatAsMeal: 1 },
        jev: [
          { threshold: 0.9, mealAsChat: 6, chatAsMeal: 0 },
          { threshold: 0.6, mealAsChat: 1, chatAsMeal: 2 },
          { threshold: 0.8, mealAsChat: 5, chatAsMeal: 0 },
          { threshold: 0.7, mealAsChat: 3, chatAsMeal: 1 },
        ],
      };
    });

    test("Jev にし、その中で一番低いしきい値にすること", () => {
      expect(decideClassificationModel(input)).toEqual({ model: "jev", threshold: 0.8 });
    });
  });

  describe("食事を会話にした間違いが、ちょうど Haiku 5.5 の数＋4 のとき", () => {
    let input: Parameters<typeof decideClassificationModel>[0];
    beforeEach(() => {
      input = {
        haiku: { mealAsChat: 0, chatAsMeal: 0 },
        jev: [{ threshold: 0.95, mealAsChat: 4, chatAsMeal: 0 }],
      };
    });

    test("Jev にすること", () => {
      expect(decideClassificationModel(input)).toEqual({ model: "jev", threshold: 0.95 });
    });
  });

  describe("会話を食事にした間違いが 0 のしきい値で、食事を会話にした間違いが Haiku 5.5 の数＋5 のとき", () => {
    let input: Parameters<typeof decideClassificationModel>[0];
    beforeEach(() => {
      input = {
        haiku: { mealAsChat: 0, chatAsMeal: 0 },
        jev: [
          { threshold: 0.9, mealAsChat: 3, chatAsMeal: 1 },
          { threshold: 0.95, mealAsChat: 5, chatAsMeal: 0 },
        ],
      };
    });

    test("Haiku 5.5 にすること", () => {
      expect(decideClassificationModel(input)).toEqual({ model: "haiku" });
    });
  });

  describe("どのしきい値でも会話を食事にした間違いがあるとき", () => {
    let input: Parameters<typeof decideClassificationModel>[0];
    beforeEach(() => {
      input = {
        haiku: { mealAsChat: 9, chatAsMeal: 3 },
        jev: [
          { threshold: 0.5, mealAsChat: 0, chatAsMeal: 4 },
          { threshold: 0.95, mealAsChat: 1, chatAsMeal: 1 },
        ],
      };
    });

    test("Haiku 5.5 の会話を食事にした間違いに関わらず、Haiku 5.5 にすること", () => {
      expect(decideClassificationModel(input)).toEqual({ model: "haiku" });
    });
  });
});
