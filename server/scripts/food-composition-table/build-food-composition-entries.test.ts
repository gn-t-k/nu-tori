import { beforeEach, describe, expect, test } from "vitest";
import { nutrientSourceColumns } from "../../src/domain/food-composition/nutrient-source-columns";
import { buildFoodCompositionEntries } from "./build-food-composition-entries";

// 本表の「表全体」シートと同じ並びの小さな表を作る。0 列目が食品群、1 列目が食品番号、3 列目が食品名
const identifiers = [...new Set(Object.values(nutrientSourceColumns).flat()), "CHOAVLM"];
const lastColumn = 4 + identifiers.length;

const headerRows = (): unknown[][] => [
  [null, null, null, null, null, "更新日：2026年3月27日"],
  [
    "食　品　群",
    "食　品　番　号",
    "索　引　番　号",
    "可　　食　　部",
    ...identifiers.map(() => null),
    "備　　考",
  ],
  [null, null, null, "食　品　名"],
  [null, null, null, "成分識別子", ...identifiers, null],
];

const foodRow = (
  foodNumber: string,
  name: string,
  cells: Record<string, unknown>,
  remarks: string | null,
): unknown[] => [
  foodNumber.slice(0, 2),
  foodNumber,
  "0001",
  name,
  ...identifiers.map((identifier) => cells[identifier] ?? null),
  remarks,
];

describe("本表のシートから食品の一覧を作る", () => {
  describe("食品の行が2つあるとき", () => {
    let rows: unknown[][];
    beforeEach(() => {
      rows = [
        ...headerRows(),
        foodRow(
          "01001",
          "アマランサス　玄穀",
          { ENERC_KCAL: 343, PROTCAA: "(11.3)", "PROT-": 12.7, CHOLE: "(0)", ID: "-" },
          "別名： オート、オーツ",
        ),
        foodRow("01002", "あわ　精白粒", { ENERC_KCAL: 346 }, null),
      ];
    });

    test("食品番号・食品名・別名・栄養の値を持つ行を、シートの並びで返すこと", () => {
      expect(buildFoodCompositionEntries(rows)).toEqual([
        {
          foodNumber: "01001",
          name: "アマランサス　玄穀",
          aliases: ["オート", "オーツ"],
          nutrients: { energy_kcal: 343, protein_g: 11.3, cholesterol_mg: 0 },
        },
        { foodNumber: "01002", name: "あわ　精白粒", aliases: [], nutrients: { energy_kcal: 346 } },
      ]);
    });
  });

  describe("食品の行の前後に、食品番号の無い行（空行・注記）があるとき", () => {
    let rows: unknown[][];
    beforeEach(() => {
      rows = [
        ...headerRows(),
        foodRow("01001", "アマランサス　玄穀", {}, null),
        [null, null, null, "注記"],
        Array.from({ length: lastColumn }, () => null),
      ];
    });

    test("食品の行だけを返すこと", () => {
      expect(buildFoodCompositionEntries(rows).map((entry) => entry.foodNumber)).toEqual(["01001"]);
    });
  });

  describe("成分識別子の行が無いとき", () => {
    let rows: unknown[][];
    beforeEach(() => {
      rows = [[null, null, null, "食　品　名"]];
    });

    test("列の並びが変わったとして、投げること", () => {
      expect(() => buildFoodCompositionEntries(rows)).toThrow("成分識別子");
    });
  });

  describe("栄養の項目に使う列が成分識別子の行に無いとき", () => {
    let rows: unknown[][];
    beforeEach(() => {
      rows = headerRows().map((row) => row.map((cell) => (cell === "CHOLE" ? null : cell)));
    });

    test("列の並びが変わったとして、投げること", () => {
      expect(() => buildFoodCompositionEntries(rows)).toThrow("成分識別子");
    });
  });
});
