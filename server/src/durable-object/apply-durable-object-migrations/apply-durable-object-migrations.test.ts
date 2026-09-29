import { env, runInDurableObject } from "cloudflare:test";
import { beforeEach, describe, expect, test } from "vitest";
import { applyDurableObjectMigrations, type DurableObjectMigration } from "./index";

describe("Durable Object の移行", () => {
  let account: DurableObjectStub;
  beforeEach(async () => {
    account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
    // 起動のときに本物の移行が当たっているので、何も当てていない状態に戻す
    await runInDurableObject(account, (_, state) => state.storage.deleteAll());
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

  describe("間の版を当てずに、後の版まで当ててあるとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(async () => {
      const appliedMigrations = [
        { version: 1, sql: "CREATE TABLE meals (id TEXT)" },
        { version: 2, sql: "INSERT INTO meals (id) VALUES ('meal-2')" },
        { version: 4, sql: "INSERT INTO meals (id) VALUES ('meal-4')" },
      ];
      await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, appliedMigrations);
      });
      migrations = [
        ...appliedMigrations.slice(0, 2),
        { version: 3, sql: "INSERT INTO meals (id) VALUES ('meal-3')" },
        ...appliedMigrations.slice(2),
      ];
    });

    test("当てていない間の版を当てること", async () => {
      const versions = await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
        return state.storage.sql
          .exec("SELECT version FROM durable_object_migrations ORDER BY version")
          .toArray();
      });
      expect(versions).toEqual([{ version: 1 }, { version: 2 }, { version: 3 }, { version: 4 }]);
    });

    test("当てた版を当て直さないこと", async () => {
      const meals = await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
        return state.storage.sql.exec("SELECT id FROM meals ORDER BY id").toArray();
      });
      expect(meals).toEqual([{ id: "meal-2" }, { id: "meal-3" }, { id: "meal-4" }]);
    });
  });

  describe("版の順に並んでいないとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(() => {
      migrations = [
        { version: 2, sql: "ALTER TABLE meals ADD COLUMN eaten_at TEXT" },
        { version: 1, sql: "CREATE TABLE meals (id TEXT PRIMARY KEY)" },
      ];
    });

    test("版の小さい順に当てること", async () => {
      const columns = await runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
        return state.storage.sql.exec("SELECT name FROM pragma_table_info('meals')").toArray();
      });
      expect(columns).toEqual([{ name: "id" }, { name: "eaten_at" }]);
    });
  });

  describe("同じ版が2つあるとき", () => {
    let migrations: DurableObjectMigration[];
    beforeEach(() => {
      migrations = [
        { version: 1, sql: "CREATE TABLE meals (id TEXT PRIMARY KEY)" },
        { version: 1, sql: "CREATE TABLE weights (id TEXT PRIMARY KEY)" },
      ];
    });

    test("どの版も当てないこと", async () => {
      const tables = await runInDurableObject(account, (_, state) => {
        try {
          applyDurableObjectMigrations(state.storage, migrations);
        } catch {
          // 当たった表を下で確かめる
        }
        return state.storage.sql
          .exec("SELECT name FROM sqlite_master WHERE name IN ('meals', 'weights')")
          .toArray();
      });
      expect(tables).toEqual([]);
    });

    test("重複した版を示して失敗を投げること", async () => {
      const applying = runInDurableObject(account, (_, state) => {
        applyDurableObjectMigrations(state.storage, migrations);
      });
      await expect(applying).rejects.toThrow("Durable Object の移行の版 1 が重複している");
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
