import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

// Better Auth が持たない、Apple の refresh token の表。宣言は d1-migrations/ の SQL に合わせる
export const appleRefreshTokens = sqliteTable("apple_refresh_tokens", {
  accountId: text("account_id").primaryKey(),
  keyVersion: integer("key_version").notNull(),
  ciphertext: text("ciphertext").notNull(),
});
