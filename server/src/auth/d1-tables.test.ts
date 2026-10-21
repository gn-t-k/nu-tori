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

describe("D1 の移行の 0002（課金の表）", () => {
  describe("移行を当てた DB があるとき", () => {
    let tables: string[];
    let indexes: Record<string, unknown>[];
    beforeEach(async () => {
      tables = (
        await env.DB.prepare(
          "SELECT name FROM sqlite_schema WHERE type = 'table' AND name IN ('app_account_tokens', 'app_store_subscription_routes', 'free_trial_usages', 'test_users') ORDER BY name",
        ).all<{ name: string }>()
      ).results.map(({ name }) => name);
      indexes = (
        await env.DB.prepare(
          `SELECT l.name AS name, s.name AS tbl_name, l."unique" AS is_unique, (SELECT group_concat(name) FROM pragma_index_info(l.name)) AS columns FROM sqlite_schema AS s JOIN pragma_index_list(s.name) AS l WHERE s.type = 'table' AND s.name IN ('app_account_tokens', 'app_store_subscription_routes', 'free_trial_usages') AND l.origin <> 'pk' ORDER BY l.name`,
        ).all()
      ).results;
    });

    test("課金の 4 つの表ができること", () => {
      expect(tables).toEqual([
        "app_account_tokens",
        "app_store_subscription_routes",
        "free_trial_usages",
        "test_users",
      ]);
    });

    test("3 つの一意の索引と、案内のアカウントの索引ができること", () => {
      expect(indexes).toEqual([
        {
          name: "app_account_tokens_app_account_token",
          tbl_name: "app_account_tokens",
          is_unique: 1,
          columns: "app_account_token",
        },
        {
          name: "app_store_subscription_routes_account_id",
          tbl_name: "app_store_subscription_routes",
          is_unique: 0,
          columns: "account_id",
        },
        {
          name: "app_store_subscription_routes_environment",
          tbl_name: "app_store_subscription_routes",
          is_unique: 1,
          columns: "environment,app_store_original_transaction_id",
        },
        {
          name: "free_trial_usages_apple_sub_hash",
          tbl_name: "free_trial_usages",
          is_unique: 1,
          columns: "apple_sub_hash",
        },
      ]);
    });
  });
});
