import { beforeEach, describe, expect, test } from "vitest";
import type { ClassificationLabel } from "../../../src/reply/domain/conversation-provider";
import { judgeClassificationError } from "./index";

describe("読み分けの間違いを1件ずつ数える", () => {
  describe("正解が食事で、決めかねると答えたとき", () => {
    let output: ClassificationLabel;
    beforeEach(() => {
      output = "unsure";
    });

    test("会話として、食事を会話にした間違いに数えること", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "meal" },
          config: { error: "meal_as_chat" },
        }).score,
      ).toBe(1);
    });

    test("会話を食事にした間違いには数えないこと", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "meal" },
          config: { error: "chat_as_meal" },
        }).score,
      ).toBe(0);
    });
  });

  describe("正解が食事で、食事と答えたとき", () => {
    let output: ClassificationLabel;
    beforeEach(() => {
      output = "meal";
    });

    test("食事を会話にした間違いに数えないこと", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "meal" },
          config: { error: "meal_as_chat" },
        }).score,
      ).toBe(0);
    });
  });

  describe("正解が会話で、食事と答えたとき", () => {
    let output: ClassificationLabel;
    beforeEach(() => {
      output = "meal";
    });

    test("会話を食事にした間違いに数えること", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "chat" },
          config: { error: "chat_as_meal" },
        }).score,
      ).toBe(1);
    });
  });

  describe("間違いのとき", () => {
    let output: ClassificationLabel;
    beforeEach(() => {
      output = "conversation";
    });

    test("テストを落とさず、件数を score だけで数えること", () => {
      expect(
        judgeClassificationError(output, {
          vars: { expected: "meal" },
          config: { error: "meal_as_chat" },
        }).pass,
      ).toBe(true);
    });
  });
});
