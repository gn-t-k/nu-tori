import { env, runInDurableObject } from "cloudflare:test";
import { beforeEach, describe, expect, test } from "vitest";
import { applyDurableObjectMigrations, type DurableObjectMigration } from "./index";

describe("Durable Object の移行", () => {
  let account: DurableObjectStub;
  beforeEach(() => {
    account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
  });

  describe("まだ何も当てていないとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(() => {
      migrations = [
        { version: 1, sql: "CREATE TABLE meals (id TEXT PRIMARY KEY)" },
        { version: 2, sql: "ALTER TABLE meals ADD COLUMN eaten_at TEXT" },
      ];
    });

    test("すべての版を順に当てること", async () => {
      const columns = await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
        return state.storage.sql.exec("SELECT name FROM pragma_table_info('meals')").toArray();
      });
      expect(columns).toEqual([{ name: "id" }, { name: "eaten_at" }]);
    });
  });

  describe("前の版まで当ててあるとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(async () => {
      const firstVersion = { version: 1, sql: "CREATE TABLE meals (id TEXT PRIMARY KEY)" };
      await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, [firstVersion]);
      });
      migrations = [firstVersion, { version: 2, sql: "INSERT INTO meals (id) VALUES ('meal-1')" }];
    });

    test("まだ当てていない版だけを当てること", async () => {
      const meals = await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
        return state.storage.sql.exec("SELECT id FROM meals").toArray();
      });
      expect(meals).toEqual([{ id: "meal-1" }]);
    });
  });

  describe("途中の版の SQL が失敗したとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(() => {
      migrations = [
        { version: 1, sql: "CREATE TABLE meals (id TEXT PRIMARY KEY)" },
        {
          version: 2,
          sql: "ALTER TABLE meals ADD COLUMN eaten_at TEXT; INSERT INTO missing (id) VALUES (1)",
        },
      ];
    });

    test("失敗した版を丸ごと戻し、前の版までを当てたままにすること", async () => {
      const result = await runInDurableObject(account, (_, state) => {
        try {
          applyDurableObjectMigrations(state.storage, migrations);
        } catch {
          // 当たった版を下で確かめる
        }
        return {
          versions: state.storage.sql
            .exec("SELECT version FROM durable_object_migrations")
            .toArray(),
          columns: state.storage.sql.exec("SELECT name FROM pragma_table_info('meals')").toArray(),
        };
      });
      expect(result).toEqual({ versions: [{ version: 1 }], columns: [{ name: "id" }] });
    });

    test("失敗を投げること", async () => {
      const applying = runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
      });
      await expect(applying).rejects.toThrow("no such table: missing");
    });
  });
});
