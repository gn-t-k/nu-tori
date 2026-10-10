import { describe, expect, test } from "vitest";
import { judgeReplyShape, type ReplyShapeConfig } from "./index";

const salad = "7d1c2a4e-3b5f-4c8a-9e6d-000000000112";
const ramen = "7d1c2a4e-3b5f-4c8a-9e6d-000000000103";
const unknown = "7d1c2a4e-3b5f-4c8a-9e6d-000000000999";

const config: ReplyShapeConfig = {
  maxLength: 10,
  referableMealIds: [salad, ramen],
  expectedMealIds: [],
};

describe("返事の長さと指し示す食事を確かめる", () => {
  test("長さが上限ちょうどで、指し示す食事が無ければ通ること", () => {
    expect(
      judgeReplyShape("あいうえおかきくけこ", { config, metadata: { mealIds: [] } }).pass,
    ).toBe(true);
  });

  test("長さが上限を超えたら落ち、理由に字数が出ること", () => {
    expect(
      judgeReplyShape("あいうえおかきくけこさ", { config, metadata: { mealIds: [] } }),
    ).toEqual({ pass: false, score: 0, reason: "11 字（上限 10 字）" });
  });

  test("文脈で ID を付けていない食事を指し示したら落ちること", () => {
    expect(judgeReplyShape("直してください", { config, metadata: { mealIds: [unknown] } })).toEqual(
      {
        pass: false,
        score: 0,
        reason: `文脈で ID を付けていない食事を指し示した: ${unknown}`,
      },
    );
  });

  test("指し示してほしい食事を指し示していれば通ること", () => {
    expect(
      judgeReplyShape("直してください", {
        config: { ...config, expectedMealIds: [salad] },
        metadata: { mealIds: [ramen, salad] },
      }).pass,
    ).toBe(true);
  });

  test("指し示してほしい食事を指し示していなければ落ちること", () => {
    expect(
      judgeReplyShape("直してください", {
        config: { ...config, expectedMealIds: [salad] },
        metadata: { mealIds: [ramen] },
      }),
    ).toEqual({
      pass: false,
      score: 0,
      reason: `指し示してほしい食事を指し示していない: ${salad}`,
    });
  });

  test("提供元が指し示す食事を返していなければ、設定の誤りとして投げること", () => {
    expect(() => judgeReplyShape("こんにちは", { config, metadata: undefined })).toThrow(
      "返事の提供元が metadata.mealIds を返していない",
    );
  });
});
