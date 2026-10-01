import { env, runInDurableObject } from "cloudflare:test";
import { getTableConfig } from "drizzle-orm/sqlite-core";
import { beforeEach, describe, expect, test } from "vitest";
import {
  type ActualColumn,
  findTableDeclarationMismatches,
} from "../testing/find-table-declaration-mismatches";
import { durableObjectTables } from "./durable-object-tables";

describe("Durable Object の表の宣言", () => {
  describe("移行を当てた DB があるとき", () => {
    let actualColumnsByTable: Map<string, ActualColumn[]>;
    beforeEach(async () => {
      const account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      actualColumnsByTable = await runInDurableObject(account, (_, state) => {
        const tableNames = state.storage.sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' AND name <> 'durable_object_migrations'",
          )
          .toArray()
          .map((row) => row.name);
        return new Map(
          tableNames.map((name) => [
            name,
            state.storage.sql
              .exec<ActualColumn>(
                `SELECT name, type, "notnull", pk FROM pragma_table_info(?)`,
                name,
              )
              .toArray(),
          ]),
        );
      });
    });

    test("DB の表がすべて宣言されていること", () => {
      const declaredNames = Object.values(durableObjectTables).map(
        (table) => getTableConfig(table).name,
      );
      expect([...actualColumnsByTable.keys()].toSorted()).toEqual(declaredNames.toSorted());
    });

    test("宣言の列が DB の実際の列と合っていること", () => {
      const mismatches = Object.values(durableObjectTables).flatMap((table) =>
        findTableDeclarationMismatches(
          table,
          actualColumnsByTable.get(getTableConfig(table).name) ?? [],
        ),
      );
      expect(mismatches).toEqual([]);
    });
  });
});
