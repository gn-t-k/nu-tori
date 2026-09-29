import createFirstSignIns from "../../durable-object-migrations/0001_create_first_sign_ins.sql";
import type { DurableObjectMigration } from "./apply-durable-object-migrations";

// 版の順に並べる。SQL は ../../durable-object-migrations/ に置き、import で読む
export const durableObjectMigrations: readonly DurableObjectMigration[] = [
  { version: 1, sql: createFirstSignIns },
];
