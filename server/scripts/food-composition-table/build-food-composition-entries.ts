import type { FoodCompositionEntry } from "../../src/domain/food-composition/food-composition-entry";
import { nutrientSourceColumns } from "../../src/domain/food-composition/nutrient-source-columns";
import { readAliases } from "./read-aliases";
import { readNutrientValues } from "./read-nutrient-values";

// 本表の「表全体」シートの行から、食品の一覧を作る
// 列は、見出しの文字（食品番号・食品名・備考）と成分識別子の行から探す。並びが変わっていたら、読み違えずに投げる
export const buildFoodCompositionEntries = (rows: readonly Row[]): FoodCompositionEntry[] => {
  const identifierRowIndex = rows.findIndex((row) => row.includes("成分識別子"));
  const identifierRow = rows[identifierRowIndex];
  if (identifierRow === undefined) {
    throw new Error("成分識別子の行が見つからない");
  }
  const headerRows = rows.slice(0, identifierRowIndex + 1);
  const foodNumberColumn = findHeaderColumn(headerRows, "食品番号");
  const nameColumn = findHeaderColumn(headerRows, "食品名");
  const remarksColumn = findHeaderColumn(headerRows, "備考");

  const componentColumns = new Map<string, number>();
  identifierRow.forEach((cell, column) => {
    if (typeof cell === "string" && cell !== "成分識別子") {
      componentColumns.set(cell, column);
    }
  });
  for (const columns of Object.values(nutrientSourceColumns)) {
    for (const column of columns) {
      if (!componentColumns.has(column)) {
        throw new Error(`成分識別子 ${column} の列が見つからない`);
      }
    }
  }

  return rows.slice(identifierRowIndex + 1).flatMap((row) => {
    const foodNumber = row[foodNumberColumn];
    const name = row[nameColumn];
    if (typeof foodNumber !== "string" || !/^[0-9]{5}$/.test(foodNumber)) {
      return [];
    }
    if (typeof name !== "string") {
      throw new Error(`食品番号 ${foodNumber} の食品名が文字列でない`);
    }
    const components = Object.fromEntries(
      [...componentColumns].map(([identifier, column]) => [identifier, row[column]]),
    );
    return [
      {
        foodNumber,
        name,
        aliases: readAliases(row[remarksColumn]),
        nutrients: readNutrientValues(components),
      },
    ];
  });
};

type Row = readonly unknown[];

// 見出しは字の間に全角スペースが入っている（食品番号が「食 品 番 号」の形）ので、空白を除いて比べる
const findHeaderColumn = (headerRows: readonly Row[], label: string): number => {
  for (const row of headerRows) {
    const column = row.findIndex(
      (cell) => typeof cell === "string" && cell.replaceAll(/\s/g, "") === label,
    );
    if (column !== -1) {
      return column;
    }
  }
  throw new Error(`見出し ${label} の列が見つからない`);
};
