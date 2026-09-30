import { env } from "cloudflare:workers";
import { getTableConfig } from "drizzle-orm/sqlite-core";
import { beforeEach, describe, expect, test } from "vitest";
import {
  type ActualColumn,
  findTableDeclarationMismatches,
} from "../testing/find-table-declaration-mismatches";
import { d1Tables } from "./d1-tables";

describe("D1 の表の宣言", () => {
  describe("移行を当てた DB があるとき", () => {
    let actualColumnsByTable: Map<string, ActualColumn[]>;
    beforeEach(async () => {
      const { results } = await env.DB.prepare(
        "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' AND name <> 'd1_migrations'",
      ).all<{ name: string }>();
      actualColumnsByTable = new Map(
        await Promise.all(
          results.map(async ({ name }) => {
            const columns = await env.DB.prepare(
              `SELECT name, type, "notnull", pk FROM pragma_table_info(?)`,
            )
              .bind(name)
              .all<ActualColumn>();
            return [name, columns.results] as const;
          }),
        ),
      );
    });

    test("DB の表がすべて宣言されていること", () => {
      const declaredNames = Object.values(d1Tables).map((table) => getTableConfig(table).name);
      expect([...actualColumnsByTable.keys()].toSorted()).toEqual(declaredNames.toSorted());
    });

    test("宣言の列が DB の実際の列と合っていること", () => {
      const mismatches = Object.values(d1Tables).flatMap((table) =>
        findTableDeclarationMismatches(
          table,
          actualColumnsByTable.get(getTableConfig(table).name) ?? [],
        ),
      );
      expect(mismatches).toEqual([]);
    });
  });
});
