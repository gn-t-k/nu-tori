import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 消した記録の控えから辿れてよい表。足すときは、足した理由をここに書く
const tablesAllowedToKeepRows = [
  // 削除の印。ID と控えだけを残す
  "meal_deletions",
  "meal_photo_deletions",
  "dish_deletions",
  "ingredient_deletions",
  // 帳簿。受け付けなかった理由と、受け取った順のつなぎ（値を持たない）
  "sync_write_rejections",
  "sync_write_record_changes",
];

type DeletedRecords = { mealIds: string[]; dishIds: string[]; ingredientIds: string[] };

// 消した食事・料理・材料について、DB に何が残ったかを読む（#332 の「テストの決定」の「消したら中身が残らないこと」）。
// 控えを外部キーで指す表を数え上げるので、あとで修正の表を足して消す口に足し忘れると、leftoverRowsByTable に出る
export const inspectDeletedContents = (accountId: string, deleted: DeletedRecords) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const { sql } = state.storage;
    const recordIds = [...deleted.mealIds, ...deleted.dishIds, ...deleted.ingredientIds];
    const receiptIdsOfDeleted = `SELECT id FROM sync_write_receipts WHERE record_type IN ('meal', 'dish', 'ingredient') AND record_id IN (${placeholders(recordIds)})`;
    // Cloudflare の内部の表（_cf_ で始まる）は pragma で読めないので除く
    const tablesReferringToReceipts = sql
      .exec<{ name: string }>(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' ORDER BY name",
      )
      .toArray()
      .flatMap(({ name }) =>
        sql
          .exec<{ column: string }>(
            `SELECT "from" AS column FROM pragma_foreign_key_list(?) WHERE "table" = 'sync_write_receipts'`,
            name,
          )
          .toArray()
          .map(({ column }) => ({ name, column })),
      )
      .filter(({ name }) => !tablesAllowedToKeepRows.includes(name));
    const leftoverRowsByTable = Object.fromEntries(
      tablesReferringToReceipts.flatMap(({ name, column }) => {
        const { total } = sql
          .exec<{ total: number }>(
            `SELECT count(*) AS total FROM "${name}" WHERE "${column}" IN (${receiptIdsOfDeleted})`,
            ...recordIds,
          )
          .one();
        return total === 0 ? [] : [[name, total]];
      }),
    );
    const countWhereIn = (table: string, column: string, ids: string[]): number =>
      sql
        .exec<{ total: number }>(
          `SELECT count(*) AS total FROM "${table}" WHERE "${column}" IN (${placeholders(ids)})`,
          ...ids,
        )
        .one().total;
    const scheduleIdsOfDishes = `SELECT estimation_schedule_id FROM dish_estimation_schedules WHERE dish_id IN (${placeholders(deleted.dishIds)})`;
    return {
      tablesReferringToReceipts: tablesReferringToReceipts.map(({ name }) => name),
      leftoverRowsByTable,
      contentCounts: {
        dishes: countWhereIn("dishes", "id", deleted.dishIds),
        estimationApplications: countWhereIn(
          "dish_estimation_applications",
          "dish_id",
          deleted.dishIds,
        ),
        estimatedQuantities: countWhereIn("dish_estimated_quantities", "dish_id", deleted.dishIds),
        ingredients: countWhereIn("ingredients", "id", deleted.ingredientIds),
        ingredientNutrients: countWhereIn(
          "ingredient_nutrients",
          "ingredient_id",
          deleted.ingredientIds,
        ),
        foodCompositionIngredients: countWhereIn(
          "food_composition_ingredients",
          "ingredient_id",
          deleted.ingredientIds,
        ),
        proportions: countWhereIn(
          "dish_quantity_correction_ingredients",
          "ingredient_id",
          deleted.ingredientIds,
        ),
        dishScheduleLinks: countWhereIn("dish_estimation_schedules", "dish_id", deleted.dishIds),
        // つなぎが消えると取り消しも消えるので、取り消しは数え上げのほうでも 0 になる
        cancellationsOfLinkedSchedules: sql
          .exec<{ total: number }>(
            `SELECT count(*) AS total FROM estimation_schedule_cancellations WHERE estimation_schedule_id IN (${scheduleIdsOfDishes})`,
            ...deleted.dishIds,
          )
          .one().total,
        meals: countWhereIn("meals", "id", deleted.mealIds),
      },
      // 削除の印ごとの、消した書き込みの控え
      dishDeletionReceipts: readDeletionReceipts(sql, "dish_deletions", "dish_id", deleted.dishIds),
      ingredientDeletionReceipts: readDeletionReceipts(
        sql,
        "ingredient_deletions",
        "ingredient_id",
        deleted.ingredientIds,
      ),
      foreignKeyViolations: sql.exec("PRAGMA foreign_key_check").toArray(),
    };
  });

const readDeletionReceipts = (
  sql: DurableObjectStorage["sql"],
  table: string,
  column: string,
  ids: string[],
) =>
  Object.fromEntries(
    sql
      .exec<{ id: string; kind: string; recordType: string; recordId: string }>(
        `SELECT d."${column}" AS id, r.kind AS kind, r.record_type AS recordType, r.record_id AS recordId
         FROM "${table}" AS d JOIN sync_write_receipts AS r ON r.id = d.sync_write_receipt_id
         WHERE d."${column}" IN (${placeholders(ids)})`,
        ...ids,
      )
      .toArray()
      .map(({ id, ...receipt }) => [id, receipt]),
  );

const placeholders = (ids: readonly string[]): string => ids.map(() => "?").join(", ") || "NULL";
