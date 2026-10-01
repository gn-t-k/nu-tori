import { describe, expect, test } from "vitest";
import { loadFoodComposition } from "./food-composition";

// 同梱の成分表のデータファイルを、本表の Excel の値と突き合わせる（食品番号は本表のもの）
describe("同梱の成分表", () => {
  describe("組成に基づくたんぱく質が括弧付きの食品（01001 アマランサス 玄穀）", () => {
    test("組成に基づく値、質量計の炭水化物、(0) の 0 を持つこと", () => {
      expect(loadFoodComposition().findByFoodNumber("01001")?.nutrients).toMatchObject({
        energy_kcal: 343,
        protein_g: 11.3,
        carbohydrate_g: 57.8,
        cholesterol_mg: 0,
      });
    });
  });

  describe("ヨウ素が「*」（第3章参照）の食品（06371 甘酢れんこん）", () => {
    test("ヨウ素を不明として、項目を持たないこと", () => {
      expect(loadFoodComposition().findByFoodNumber("06371")?.nutrients).not.toHaveProperty(
        "iodine_ug",
      );
    });
  });

  describe("利用可能炭水化物に †（規定法による測定値）が付いた食品（03032 還元水あめ）", () => {
    test("† を外した値を持つこと", () => {
      expect(loadFoodComposition().findByFoodNumber("03032")?.nutrients).toMatchObject({
        carbohydrate_g: 18.5,
        fiber_g: 14,
      });
    });
  });

  describe("鶏むね肉（皮なし・生）の候補を探すとき", () => {
    test("若どりと親の、むね 皮なし 生の食品が先に出ること", () => {
      expect(
        loadFoodComposition()
          .findCandidates("鶏むね肉 皮なし 生", 3)
          .map((entry) => entry.foodNumber)
          .toSorted(),
      ).toEqual(expect.arrayContaining(["11214", "11220"]));
    });
  });
});
