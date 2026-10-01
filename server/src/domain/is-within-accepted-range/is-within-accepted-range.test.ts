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
});
