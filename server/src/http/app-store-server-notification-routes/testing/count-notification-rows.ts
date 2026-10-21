import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

const countedTables = [
  "subscription_receipts",
  "app_store_notification_receipts",
  "subscriptions",
  "subscription_transactions",
  "subscription_transaction_revocations",
  "subscription_transaction_revocation_reversals",
  "subscription_billing_failures",
  "subscription_grace_periods",
] as const;

// App Store のサーバー通知が書く表ごとの行の数
export const countNotificationRows = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    Object.fromEntries(
      countedTables.map((table) => [
        table,
        state.storage.sql.exec<{ count: number }>(`SELECT count(*) AS count FROM ${table}`).one()
          .count,
      ]),
    ),
  );
