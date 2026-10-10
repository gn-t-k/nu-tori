import { beforeEach, describe, expect, test } from "vitest";
import { judgeReplyShape, type ReplyShapeConfig } from "./index";

describe("返事の長さと指し示す食事を確かめる", () => {
  const salad = "7d1c2a4e-3b5f-4c8a-9e6d-000000000112";
  const ramen = "7d1c2a4e-3b5f-4c8a-9e6d-000000000103";
  const unknown = "7d1c2a4e-3b5f-4c8a-9e6d-000000000999";

  describe("長さ", () => {
    let config: ReplyShapeConfig;
    let metadata: unknown;
    beforeEach(() => {
      config = { maxLength: 10, referableMealIds: [salad, ramen], expectedMealIds: [] };
      metadata = { mealIds: [] };
    });

    describe("上限ちょうどで、指し示す食事が無いとき", () => {
      let output: string;
      beforeEach(() => {
        output = "あいうえおかきくけこ";
      });

      test("通ること", () => {
        expect(judgeReplyShape(output, { config, metadata }).pass).toBe(true);
      });
    });

    describe("上限を超えたとき", () => {
      let output: string;
      beforeEach(() => {
        output = "あいうえおかきくけこさ";
      });

      test("落ち、理由に字数が出ること", () => {
        expect(judgeReplyShape(output, { config, metadata })).toEqual({
          pass: false,
          score: 0,
          reason: "11 字（上限 10 字）",
        });
      });
    });

    describe("UTF-16 で2単位の文字（絵文字）を含むとき", () => {
      let output: string;
      beforeEach(() => {
        output = "あいうえおかきくけ🍙";
      });

      test("1字と数え、上限ちょうどで通ること", () => {
        expect(judgeReplyShape(output, { config, metadata }).pass).toBe(true);
      });
    });
  });

  describe("指し示す食事", () => {
    describe("文脈で ID を付けていない食事を指し示したとき", () => {
      let output: string;
      let config: ReplyShapeConfig;
      let metadata: unknown;
      beforeEach(() => {
        output = "直してください";
        config = { maxLength: 10, referableMealIds: [salad, ramen], expectedMealIds: [] };
        metadata = { mealIds: [unknown] };
      });

      test("落ちること", () => {
        expect(judgeReplyShape(output, { config, metadata })).toEqual({
          pass: false,
          score: 0,
          reason: `文脈で ID を付けていない食事を指し示した: ${unknown}`,
        });
      });
    });

    describe("指し示してほしい食事があるとき", () => {
      let output: string;
      let config: ReplyShapeConfig;
      beforeEach(() => {
        output = "直してください";
        config = { maxLength: 10, referableMealIds: [salad, ramen], expectedMealIds: [salad] };
      });

      describe("指し示しているとき", () => {
        let metadata: unknown;
        beforeEach(() => {
          metadata = { mealIds: [ramen, salad] };
        });

        test("通ること", () => {
          expect(judgeReplyShape(output, { config, metadata }).pass).toBe(true);
        });
      });

      describe("指し示していないとき", () => {
        let metadata: unknown;
        beforeEach(() => {
          metadata = { mealIds: [ramen] };
        });

        test("落ちること", () => {
          expect(judgeReplyShape(output, { config, metadata })).toEqual({
            pass: false,
            score: 0,
            reason: `指し示してほしい食事を指し示していない: ${salad}`,
          });
        });
      });
    });

    describe("提供元が指し示す食事を返していないとき", () => {
      let output: string;
      let config: ReplyShapeConfig;
      let metadata: unknown;
      beforeEach(() => {
        output = "こんにちは";
        config = { maxLength: 10, referableMealIds: [salad, ramen], expectedMealIds: [] };
        metadata = undefined;
      });

      test("設定の誤りとして投げること", () => {
        expect(() => judgeReplyShape(output, { config, metadata })).toThrow(
          "返事の提供元が metadata.mealIds を返していない",
        );
      });
    });
  });
});
