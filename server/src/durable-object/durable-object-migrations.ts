import createFirstSignIns from "../../durable-object-migrations/0001_create_first_sign_ins.sql";
import createSyncTables from "../../durable-object-migrations/0002_create_sync_tables.sql";
import createWeightRecordDeletions from "../../durable-object-migrations/0003_create_weight_record_deletions.sql";
import createAccountSettings from "../../durable-object-migrations/0004_create_account_settings.sql";
import createMealTables from "../../durable-object-migrations/0005_create_meal_tables.sql";
import createNoticeAndUsualWeighingTimeTables from "../../durable-object-migrations/0006_create_notice_and_usual_weighing_time_tables.sql";
import rebuildDishAndIngredientTables from "../../durable-object-migrations/0007_rebuild_dish_and_ingredient_tables.sql";
import type { DurableObjectMigration } from "./apply-durable-object-migrations";

// 版の順に並べる。SQL は ../../durable-object-migrations/ に置き、import で読む
export const durableObjectMigrations: readonly DurableObjectMigration[] = [
  { version: 1, sql: createFirstSignIns },
  { version: 2, sql: createSyncTables },
  { version: 3, sql: createWeightRecordDeletions },
  { version: 4, sql: createAccountSettings },
  { version: 5, sql: createMealTables },
  { version: 6, sql: createNoticeAndUsualWeighingTimeTables },
  { version: 7, sql: rebuildDishAndIngredientTables },
];
