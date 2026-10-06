import { describe, expect, test } from "vitest";
import testCases from "../../../../shared/accepted-ranges.test-cases.json";
import { isWithinAcceptedRange } from "./index";

describe("受け付ける値の範囲", () => {
  describe("体重", () => {
    test.for(testCases.weightKilograms)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("weightKilograms", value)).toBe(accepted);
      },
    );
  });

  describe("体脂肪率", () => {
    test.for(testCases.bodyFatPercentage)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("bodyFatPercentage", value)).toBe(accepted);
      },
    );
  });

  describe("食事の写真の枚数", () => {
    test.for(testCases.mealPhotoCount)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("mealPhotoCount", value)).toBe(accepted);
      },
    );
  });

  describe("食事の時差", () => {
    test.for(testCases.mealUtcOffsetSeconds)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("mealUtcOffsetSeconds", value)).toBe(accepted);
      },
    );
  });

  describe("料理の量", () => {
    test.for(testCases.dishQuantity)("$name を受け付けるかを決めること", ({ value, accepted }) => {
      expect(isWithinAcceptedRange("dishQuantity", value)).toBe(accepted);
    });
  });

  describe("材料の量", () => {
    test.for(testCases.ingredientQuantity)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("ingredientQuantity", value)).toBe(accepted);
      },
    );
  });

  describe("料理の名前の、前後の空白を除いた文字数", () => {
    test.for(testCases.dishNameTrimmedLength)(
      "$name を受け付けるかを決めること",
      ({ value, accepted }) => {
        expect(isWithinAcceptedRange("dishNameTrimmedLength", value)).toBe(accepted);
      },
    );
  });
});
