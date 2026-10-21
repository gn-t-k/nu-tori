import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

const countedTables = [
  "subscription_receipts",
  "subscriptions",
  "app_store_subscriptions",
  "subscription_transactions",
  "app_store_subscription_transactions",
  "subscription_transaction_report_receipts",
] as const;

// 取引の知らせが書く表ごとの行の数
export const countSubscriptionRows = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    Object.fromEntries(
      countedTables.map((table) => [
        table,
        state.storage.sql.exec<{ count: number }>(`SELECT count(*) AS count FROM ${table}`).one()
          .count,
      ]),
    ),
  );
