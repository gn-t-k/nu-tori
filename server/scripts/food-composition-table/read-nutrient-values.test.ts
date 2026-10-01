import { beforeEach, describe, expect, test } from "vitest";
import { readNutrientValues } from "./read-nutrient-values";

describe("食品1行の成分から栄養の値を読む", () => {
  describe("組成に基づくたんぱく質が値を持つとき（推計値の括弧付き）", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { PROTCAA: "(11.3)", "PROT-": 12.7 };
    });

    test("従来のたんぱく質でなく、組成に基づく値を使うこと", () => {
      expect(readNutrientValues(components).protein_g).toBe(11.3);
    });
  });

  describe("組成に基づくたんぱく質が「-」のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { PROTCAA: "-", "PROT-": 12.7 };
    });

    test("従来のたんぱく質を使うこと", () => {
      expect(readNutrientValues(components).protein_g).toBe(12.7);
    });
  });

  describe("組成に基づくたんぱく質が (0) のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { PROTCAA: "(0)", "PROT-": 0.1 };
    });

    test("0 は値なので、従来の値に切り替えず 0 を使うこと", () => {
      expect(readNutrientValues(components).protein_g).toBe(0);
    });
  });

  describe("組成に基づく脂質（トリアシルグリセロール当量）が「-」のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { FATNLEA: "-", "FAT-": "(1.2)" };
    });

    test("従来の脂質を使うこと", () => {
      expect(readNutrientValues(components).fat_g).toBe(1.2);
    });
  });

  describe("組成に基づく脂質が値を持つとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { FATNLEA: "5.0", "FAT-": "6.0" };
    });

    test("組成に基づく値を使うこと", () => {
      expect(readNutrientValues(components).fat_g).toBe(5);
    });
  });

  describe("組成に基づくたんぱく質も従来のたんぱく質も「-」のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { PROTCAA: "-", "PROT-": "-" };
    });

    test("不明として、項目を持たないこと", () => {
      expect(readNutrientValues(components)).not.toHaveProperty("protein_g");
    });
  });

  describe("炭水化物", () => {
    describe("利用可能炭水化物（質量計）が値を持つとき", () => {
      let components: Record<string, unknown>;
      beforeEach(() => {
        components = {
          CHOAVLM: 63.5,
          CHOAVL: 57.8,
          "CHOAVLDF-": 59.9,
          "CHOCDF-": 64.9,
        };
      });

      test("単糖当量や差引き法でなく、質量計を使うこと", () => {
        expect(readNutrientValues(components).carbohydrate_g).toBe(57.8);
      });
    });

    describe("質量計が「-」で、差引き法が値を持つとき", () => {
      let components: Record<string, unknown>;
      beforeEach(() => {
        components = {
          CHOAVLM: "(10.0)",
          CHOAVL: "-",
          "CHOAVLDF-": "(59.9)",
          "CHOCDF-": 64.9,
        };
      });

      test("差引き法による利用可能炭水化物を使うこと", () => {
        expect(readNutrientValues(components).carbohydrate_g).toBe(59.9);
      });
    });

    describe("質量計と差引き法が「-」のとき", () => {
      let components: Record<string, unknown>;
      beforeEach(() => {
        components = { CHOAVLM: "-", CHOAVL: "-", "CHOAVLDF-": "-", "CHOCDF-": 64.9 };
      });

      test("従来の炭水化物を使うこと", () => {
        expect(readNutrientValues(components).carbohydrate_g).toBe(64.9);
      });
    });

    describe("3つとも「-」で、単糖当量だけ値を持つとき", () => {
      let components: Record<string, unknown>;
      beforeEach(() => {
        components = { CHOAVLM: 63.5, CHOAVL: "-", "CHOAVLDF-": "-", "CHOCDF-": "-" };
      });

      test("単糖当量は使わず、不明として項目を持たないこと", () => {
        expect(readNutrientValues(components)).not.toHaveProperty("carbohydrate_g");
      });
    });
  });

  describe("コレステロールが Tr のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { CHOLE: "Tr" };
    });

    test("0 の項目を持つこと", () => {
      expect(readNutrientValues(components)).toHaveProperty("cholesterol_mg", 0);
    });
  });

  describe("ヨウ素が「-」のとき", () => {
    let components: Record<string, unknown>;
    beforeEach(() => {
      components = { ID: "-" };
    });

    test("0 にせず、項目を持たないこと", () => {
      expect(readNutrientValues(components)).not.toHaveProperty("iodine_ug");
    });
  });
});
