import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

// 帳簿にサブスクリプションの状態の変更を載せたときの状態（#881）。書き足すだけで、いちばん新しい行と今の状態を比べる。
// 状態は JSON の文字列で持ち、読み戻さない
const ledgeredSubscriptionStatuses = sqliteTable("ledgered_subscription_statuses", {
  sequence: integer("sequence").primaryKey({ autoIncrement: true }),
  status: text("status").notNull(),
  ledgeredAt: integer("ledgered_at", { mode: "timestamp_ms" }).notNull(),
});

export const subscriptionStatusTables = { ledgeredSubscriptionStatuses };
