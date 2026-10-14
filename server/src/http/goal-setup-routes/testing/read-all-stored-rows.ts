import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// その人の Durable Object と D1 の、すべての表のすべての行。残してはいけない値がどこにも無いことを確かめるのに使う
export const readAllStoredRows = async (accountId: string): Promise<unknown> => {
  const durableObject = await runInDurableObject(
    getAccountDurableObject(env, accountId),
    (_, state) =>
      state.storage.sql
        .exec<{ name: string }>(listTables)
        .toArray()
        .map(({ name }) => ({
          table: name,
          rows: state.storage.sql.exec(`SELECT * FROM "${name}"`).toArray(),
        })),
  );
  const { results: tables } = await env.DB.prepare(listTables).all<{ name: string }>();
  const d1 = await Promise.all(
    tables.map(async ({ name }) => ({
      table: name,
      rows: (await env.DB.prepare(`SELECT * FROM "${name}"`).all()).results,
    })),
  );
  return { durableObject, d1 };
};

const listTables =
  "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\'";
