import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { termsAgreementScreens } from "../domain/terms-agreement-screens";

// 規約への同意（#647）。ID は、同意のシートでは端末が振った要求の ID、サインインの画面ではサーバーが出す UUID。
// 規約の版はコードの定数で、表にしない
const termsAgreements = sqliteTable("terms_agreements", {
  id: text("id").$type<RecordId>().primaryKey(),
  termsVersion: text("terms_version").notNull(),
  agreementScreen: text("agreement_screen", { enum: termsAgreementScreens }).notNull(),
  agreedAt: integer("agreed_at", { mode: "timestamp_ms" }).notNull(),
});

// 書き足すだけ。宣言は durable-object-migrations/ の SQL に合わせる
export const termsAgreementTables = { termsAgreements };
