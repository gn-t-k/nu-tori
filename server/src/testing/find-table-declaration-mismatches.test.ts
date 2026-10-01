import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { beforeEach, describe, expect, test } from "vitest";
import {
  type ActualColumn,
  findTableDeclarationMismatches,
} from "./find-table-declaration-mismatches";

describe("表の宣言と DB の列のずれを見つけること", () => {
  let actualColumns: ActualColumn[];
  beforeEach(() => {
    actualColumns = [
      { name: "id", type: "TEXT", notnull: 0, pk: 1 },
      { name: "title", type: "TEXT", notnull: 1, pk: 0 },
      { name: "count", type: "INTEGER", notnull: 0, pk: 0 },
    ];
  });

  describe("宣言が DB の列と合っているとき", () => {
    test("ずれが無いこと", () => {
      const meals = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: integer("count"),
      });
      expect(findTableDeclarationMismatches(meals, actualColumns)).toEqual([]);
    });
  });

  describe("宣言に DB に無い列があるとき", () => {
    test("その列を報告すること", () => {
      const meals = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: integer("count"),
        note: text("note"),
      });
      expect(findTableDeclarationMismatches(meals, actualColumns)).toEqual([
        "meals.note: 宣言にあるが DB に無い",
      ]);
    });
  });

  describe("DB に宣言に無い列があるとき", () => {
    test("その列を報告すること", () => {
      const meals = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
      });
      expect(findTableDeclarationMismatches(meals, actualColumns)).toEqual([
        "meals.count: DB にあるが宣言に無い",
      ]);
    });
  });

  describe("列の型が違うとき", () => {
    test("その列を報告すること", () => {
      const meals = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: text("count"),
      });
      expect(findTableDeclarationMismatches(meals, actualColumns)).toEqual([
        "meals.count: type が違う（宣言 text、DB integer）",
      ]);
    });
  });

  describe("NOT NULL が違うとき", () => {
    test("その列を報告すること", () => {
      const meals = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title"),
        count: integer("count"),
      });
      expect(findTableDeclarationMismatches(meals, actualColumns)).toEqual([
        "meals.title: notNull が違う（宣言 false、DB true）",
      ]);
    });
  });
});
