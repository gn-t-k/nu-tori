import type { AnySQLiteColumn, SQLiteTable } from "drizzle-orm/sqlite-core";

// 控えだけを指す修正の表（料理の名前・量、材料の量、食事の時刻、体重記録の体重と時刻）。修正した記録は、控えの record_type と record_id で引く
export type CorrectionTable = SQLiteTable & { syncWriteReceiptId: AnySQLiteColumn };
