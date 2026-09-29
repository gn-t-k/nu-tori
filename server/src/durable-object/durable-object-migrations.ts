import createFirstSignIns from "../../durable-object-migrations/0001_create_first_sign_ins.sql";
import createSyncTables from "../../durable-object-migrations/0002_create_sync_tables.sql";
import createWeightRecordDeletions from "../../durable-object-migrations/0003_create_weight_record_deletions.sql";
import type { DurableObjectMigration } from "./apply-durable-object-migrations";

// 版の順に並べる。SQL は ../../durable-object-migrations/ に置き、import で読む
export const durableObjectMigrations: readonly DurableObjectMigration[] = [
  { version: 1, sql: createFirstSignIns },
  { version: 2, sql: createSyncTables },
  { version: 3, sql: createWeightRecordDeletions },
];
