import {
  integer,
  primaryKey,
  real,
  type SQLiteTable,
  sqliteTable,
  text,
} from "drizzle-orm/sqlite-core";
import { beforeEach, describe, expect, test } from "vitest";
import {
  type ActualColumn,
  findTableDeclarationMismatches,
} from "./find-table-declaration-mismatches";

describe("表の宣言と DB の列のずれを見つけること", () => {
  let actualColumns: ActualColumn[];
  let declared: SQLiteTable;
  beforeEach(() => {
    actualColumns = [
      { name: "id", type: "TEXT", notnull: 0, pk: 1 },
      { name: "title", type: "TEXT", notnull: 1, pk: 0 },
      { name: "count", type: "INTEGER", notnull: 0, pk: 0 },
    ];
  });

  describe("宣言が DB の列と合っているとき", () => {
    beforeEach(() => {
      declared = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: integer("count"),
      });
    });

    test("ずれが無いこと", () => {
      expect(findTableDeclarationMismatches(declared, actualColumns)).toEqual([]);
    });
  });

  describe("宣言に DB に無い列があるとき", () => {
    beforeEach(() => {
      declared = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: integer("count"),
        note: text("note"),
      });
    });

    test("その列を報告すること", () => {
      expect(findTableDeclarationMismatches(declared, actualColumns)).toEqual([
        "meals.note: 宣言にあるが DB に無い",
      ]);
    });
  });

  describe("DB に宣言に無い列があるとき", () => {
    beforeEach(() => {
      declared = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
      });
    });

    test("その列を報告すること", () => {
      expect(findTableDeclarationMismatches(declared, actualColumns)).toEqual([
        "meals.count: DB にあるが宣言に無い",
      ]);
    });
  });

  describe("列の型が違うとき", () => {
    beforeEach(() => {
      declared = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title").notNull(),
        count: text("count"),
      });
    });

    test("その列を報告すること", () => {
      expect(findTableDeclarationMismatches(declared, actualColumns)).toEqual([
        "meals.count: type が違う（宣言 text、DB integer）",
      ]);
    });
  });

  describe("NOT NULL が違うとき", () => {
    beforeEach(() => {
      declared = sqliteTable("meals", {
        id: text("id").primaryKey(),
        title: text("title"),
        count: integer("count"),
      });
    });

    test("その列を報告すること", () => {
      expect(findTableDeclarationMismatches(declared, actualColumns)).toEqual([
        "meals.title: notNull が違う（宣言 false、DB true）",
      ]);
    });
  });

  describe("主キーが複数の列の組のとき", () => {
    let pairColumns: ActualColumn[];
    beforeEach(() => {
      pairColumns = [
        { name: "dish_id", type: "TEXT", notnull: 1, pk: 1 },
        { name: "estimation_id", type: "TEXT", notnull: 1, pk: 2 },
        { name: "quantity", type: "REAL", notnull: 1, pk: 0 },
      ];
    });

    describe("組の主キーで宣言しているとき", () => {
      beforeEach(() => {
        declared = sqliteTable(
          "applications",
          {
            dishId: text("dish_id").notNull(),
            estimationId: text("estimation_id").notNull(),
            quantity: real("quantity").notNull(),
          },
          (table) => [primaryKey({ columns: [table.dishId, table.estimationId] })],
        );
      });

      test("ずれが無いこと", () => {
        expect(findTableDeclarationMismatches(declared, pairColumns)).toEqual([]);
      });
    });

    describe("組の主キーを宣言し忘れたとき", () => {
      beforeEach(() => {
        declared = sqliteTable("applications", {
          dishId: text("dish_id").notNull(),
          estimationId: text("estimation_id").notNull(),
          quantity: real("quantity").notNull(),
        });
      });

      test("その列を報告すること", () => {
        expect(findTableDeclarationMismatches(declared, pairColumns)).toEqual([
          "applications.dish_id: primaryKey が違う（宣言 false、DB true）",
          "applications.estimation_id: primaryKey が違う（宣言 false、DB true）",
        ]);
      });
    });
  });
});
