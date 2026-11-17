import { beforeEach, describe, expect, test } from "vitest";
import type {
  IdentifiedDishes,
  IdentifiedIngredient,
} from "../../../src/estimation/domain/estimation-provider";
import type { NutritionLabelCase } from "../nutrition-label-case";
import { judgeNutritionLabelRun } from "./index";

describe("表示の読み取りの1回分の答えを正解と比べる", () => {
  let ramenLabel: NonNullable<IdentifiedIngredient["nutritionLabel"]>;
  let ramen: IdentifiedIngredient;
  let rice: IdentifiedIngredient;
  beforeEach(() => {
    ramenLabel = {
      basisGrams: 420,
      basisGramsEstimated: false,
      nutrients: {
        energy_kcal: 500,
        protein_g: 20.5,
        fat_g: 15,
        carbohydrate_g: 70,
        salt_equivalent_g: 6.1,
      },
    };
    ramen = {
      name: "とりそばラーメン",
      quantity: 1,
      unit: "食",
      edibleGrams: 420,
      foodCompositionQuery: "ラーメン",
      nutritionLabel: ramenLabel,
    };
    rice = {
      name: "ご飯",
      quantity: 1,
      unit: "杯",
      edibleGrams: 200,
      foodCompositionQuery: "めし 精白米",
      nutritionLabel: undefined,
    };
  });

  describe("料理まるごとの表示のケース", () => {
    let labeledCase: NutritionLabelCase;
    beforeEach(() => {
      labeledCase = {
        target: { type: "meal" },
        expected: {
          type: "labeled",
          dishes: [
            {
              nameIncludes: ["とりそば"],
              ingredients: [
                {
                  source: "nutrition_label",
                  nutrients: {
                    energy_kcal: 500,
                    protein_g: 20,
                    fat_g: 15,
                    carbohydrate_g: 70,
                    salt_equivalent_g: 6.1,
                  },
                },
              ],
            },
          ],
        },
      };
    });

    describe("表示の材料1つで、値が許す差に収まるとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [{ name: "とりそばラーメン", quantity: 1, unit: "食", ingredients: [ramen] }],
        };
      });

      test("通ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({ type: "passed" });
      });
    });

    describe("表示が 100 g あたりで、食べた分の g から表示の値になるとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [
                {
                  ...ramen,
                  edibleGrams: 400,
                  nutritionLabel: {
                    basisGrams: 100,
                    basisGramsEstimated: false,
                    nutrients: {
                      energy_kcal: 125,
                      protein_g: 5,
                      fat_g: 3.75,
                      carbohydrate_g: 17.5,
                      salt_equivalent_g: 1.5,
                    },
                  },
                },
              ],
            },
          ],
        };
      });

      test("通ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({ type: "passed" });
      });
    });

    describe("エネルギーが表示から 1 より離れたとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [
                {
                  ...ramen,
                  nutritionLabel: {
                    ...ramenLabel,
                    nutrients: { ...ramenLabel.nutrients, energy_kcal: 480 },
                  },
                },
              ],
            },
          ],
        };
      });

      test("落ち、理由に答えと表示の値が出ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "「とりそばラーメン」のエネルギー 480（表示 500）",
        });
      });
    });

    describe("食塩相当量が表示とちょうど 0.1 離れたとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [
                {
                  ...ramen,
                  nutritionLabel: {
                    ...ramenLabel,
                    nutrients: { ...ramenLabel.nutrients, salt_equivalent_g: 6.2 },
                  },
                },
              ],
            },
          ],
        };
      });

      test("通ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({ type: "passed" });
      });
    });

    describe("食塩相当量が表示から 0.1 より離れたとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [
                {
                  ...ramen,
                  nutritionLabel: {
                    ...ramenLabel,
                    nutrients: { ...ramenLabel.nutrients, salt_equivalent_g: 5.1 },
                  },
                },
              ],
            },
          ],
        };
      });

      test("落ち、理由に答えと表示の値が出ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "「とりそばラーメン」の食塩相当量 5.1（表示 6.1）",
        });
      });
    });

    describe("表示に書かれた食塩相当量を答えなかったとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        const { salt_equivalent_g: _salt, ...withoutSalt } = ramenLabel.nutrients;
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [
                { ...ramen, nutritionLabel: { ...ramenLabel, nutrients: withoutSalt } },
              ],
            },
          ],
        };
      });

      test("落ちること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "「とりそばラーメン」の食塩相当量が不明（表示 6.1）",
        });
      });
    });

    describe("書かれた表示の基準の g を取り違え、本番の検証で落ちる答えのとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            {
              name: "とりそばラーメン",
              quantity: 1,
              unit: "食",
              ingredients: [{ ...ramen, nutritionLabel: { ...ramenLabel, basisGrams: 1 } }],
            },
          ],
        };
      });

      test("落ちたと数えること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "本番の検証で落ちた",
        });
      });
    });

    describe("表示を材料に分けず、成分表の材料と並べたとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            { name: "とりそばラーメン", quantity: 1, unit: "食", ingredients: [ramen, rice] },
          ],
        };
      });

      test("落ち、理由に材料の数が出ること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "「とりそばラーメン」の材料が 表示 1・成分表 1（正解 表示 1・成分表 0）",
        });
      });
    });

    describe("料理の名前が商品名でないとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = { dishes: [{ name: "ラーメン", quantity: 1, unit: "食", ingredients: [ramen] }] };
      });

      test("落ちること", () => {
        expect(judgeNutritionLabelRun(answer, labeledCase)).toEqual({
          type: "failed",
          reason: "料理の名前「ラーメン」に とりそば が無い",
        });
      });
    });
  });

  describe("欄が分かれた表示のケース", () => {
    let splitCase: NutritionLabelCase;
    let noodles: IdentifiedIngredient;
    let soup: IdentifiedIngredient;
    beforeEach(() => {
      splitCase = {
        target: { type: "meal" },
        expected: {
          type: "labeled",
          dishes: [
            {
              nameIncludes: ["めん"],
              ingredients: [{ source: "nutrition_label", nutrients: { energy_kcal: 300 } }],
            },
            {
              nameIncludes: ["スープ"],
              ingredients: [{ source: "nutrition_label", nutrients: { energy_kcal: 100 } }],
            },
          ],
        },
      };
      noodles = {
        ...ramen,
        name: "めん・かやく",
        edibleGrams: 80,
        nutritionLabel: {
          basisGrams: 80,
          basisGramsEstimated: false,
          nutrients: { energy_kcal: 300 },
        },
      };
      soup = {
        ...ramen,
        name: "スープ",
        edibleGrams: 300,
        nutritionLabel: {
          basisGrams: 300,
          basisGramsEstimated: false,
          nutrients: { energy_kcal: 100 },
        },
      };
    });

    describe("答えの料理の順が正解と逆のとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            { name: "スープ", quantity: 1, unit: "食", ingredients: [soup] },
            { name: "めん・かやく", quantity: 1, unit: "食", ingredients: [noodles] },
          ],
        };
      });

      test("通ること", () => {
        expect(judgeNutritionLabelRun(answer, splitCase)).toEqual({ type: "passed" });
      });
    });
  });

  describe("推定し直しのケース", () => {
    let reestimateCase: NutritionLabelCase;
    beforeEach(() => {
      reestimateCase = {
        target: { type: "dish", name: "カレーライス" },
        expected: {
          type: "labeled",
          dishes: [
            {
              nameIncludes: [],
              ingredients: [
                { source: "food_composition" },
                { source: "nutrition_label", nutrients: { energy_kcal: 500 } },
              ],
            },
          ],
        },
      };
    });

    describe("料理を2つ答えたとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [
            { name: "カレーライス", quantity: 1, unit: "皿", ingredients: [rice, ramen] },
            { name: "ご飯", quantity: 1, unit: "杯", ingredients: [rice] },
          ],
        };
      });

      test("本番の検証で落ちたと数えること", () => {
        expect(judgeNutritionLabelRun(answer, reestimateCase)).toEqual({
          type: "failed",
          reason: "本番の検証で落ちた",
        });
      });
    });
  });

  describe("表示が写っていないケース", () => {
    let noLabelCase: NutritionLabelCase;
    beforeEach(() => {
      noLabelCase = { target: { type: "meal" }, expected: { type: "no_label" } };
    });

    describe("表示の材料が無いとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = { dishes: [{ name: "親子丼", quantity: 1, unit: "杯", ingredients: [rice] }] };
      });

      test("通ること", () => {
        expect(judgeNutritionLabelRun(answer, noLabelCase)).toEqual({ type: "passed" });
      });
    });

    describe("表示を作り出したとき", () => {
      let answer: IdentifiedDishes;
      beforeEach(() => {
        answer = {
          dishes: [{ name: "親子丼", quantity: 1, unit: "杯", ingredients: [rice, ramen] }],
        };
      });

      test("落ちること", () => {
        expect(judgeNutritionLabelRun(answer, noLabelCase)).toEqual({
          type: "failed",
          reason: "表示の材料が 1 個ある",
        });
      });
    });
  });
});
