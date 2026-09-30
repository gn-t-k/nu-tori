import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

const firstSignIns = sqliteTable("first_sign_ins", {
  id: text("id").primaryKey(),
  startedOn: text("started_on").notNull(),
  signedInAt: integer("signed_in_at", { mode: "timestamp_ms" }).notNull(),
  timeZone: text("time_zone"),
});

// 種類をまたぐ表。宣言は durable-object-migrations/ の SQL に合わせる（ずれはテストで気づく）
export const firstSignInTables = { firstSignIns };
