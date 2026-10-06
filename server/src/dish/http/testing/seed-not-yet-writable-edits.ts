import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

type Sql = DurableObjectStorage["sql"];

// まだ書き込みの口が無い直し（名前・量・材料の量の修正、推定し直し、予定の取り消し）を、
// 帳簿が書くのと同じ形（要求の控え・書き込みの控え・変更の並びとのつなぎ）で DB に直に書く。
// 「消したら中身が残らない」の前提に使う。書き込みの口を足すチケットで、その分を本物の書き込みに置き換える
// （#332 の「テストの決定」）。置き換えの済んだ分は、ここから消す
export const seedNotYetWritableEdits = (
  accountId: string,
  target: { dishId: string; ingredientId: string },
): Promise<{ replacingIngredientId: string }> =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const { sql } = state.storage;
    const requestLogId = crypto.randomUUID();
    sql.exec(
      `INSERT INTO sync_request_logs (id, device_id, received_at, time_zone, app_version, os_version, pending_write_count, pending_photo_count)
       VALUES (?, 'device', ?, 'Asia/Tokyo', '1.0', '26.0', 0, 0)`,
      requestLogId,
      Date.now(),
    );
    sql.exec(
      "INSERT INTO sync_push_logs (sync_request_log_id, is_final_batch) VALUES (?, 1)",
      requestLogId,
    );
    let position = 0;
    const insertReceipt = (recordType: string, recordId: string): string => {
      const receiptId = crypto.randomUUID();
      sql.exec(
        `INSERT INTO sync_write_receipts (id, sync_request_log_id, position_in_request, kind, record_type, record_id, result)
         VALUES (?, ?, ?, 'update', ?, ?, 'applied')`,
        receiptId,
        requestLogId,
        position,
        recordType,
        recordId,
      );
      position += 1;
      const { sequence } = sql
        .exec<{ sequence: number }>(
          "INSERT INTO record_changes (record_type, record_id) VALUES (?, ?) RETURNING sequence",
          recordType,
          recordId,
        )
        .one();
      sql.exec(
        "INSERT INTO sync_write_record_changes (record_change_sequence, sync_write_receipt_id) VALUES (?, ?)",
        sequence,
        receiptId,
      );
      return receiptId;
    };

    // 名前を2回直す。1回目の名前の修正で待った予定を、2回目で取り消す
    const firstRenameReceiptId = insertReceipt("dish", target.dishId);
    sql.exec(
      "INSERT INTO dish_name_corrections (sync_write_receipt_id, name) VALUES (?, 'カツ丼')",
      firstRenameReceiptId,
    );
    const secondRenameReceiptId = insertReceipt("dish", target.dishId);
    sql.exec(
      "INSERT INTO dish_name_corrections (sync_write_receipt_id, name) VALUES (?, 'かつ丼')",
      secondRenameReceiptId,
    );
    const cancelledScheduleId = insertDishSchedule(sql, target.dishId);
    sql.exec(
      "INSERT INTO estimation_schedule_cancellations (estimation_schedule_id, sync_write_receipt_id) VALUES (?, ?)",
      cancelledScheduleId,
      secondRenameReceiptId,
    );
    // 料理の量を比例の明細つきで直し、材料の量を直す
    const quantityReceiptId = insertReceipt("dish", target.dishId);
    sql.exec(
      "INSERT INTO dish_quantity_corrections (sync_write_receipt_id, quantity) VALUES (?, 1.5)",
      quantityReceiptId,
    );
    sql.exec(
      "INSERT INTO dish_quantity_correction_ingredients (sync_write_receipt_id, ingredient_id, quantity) VALUES (?, ?, 120)",
      quantityReceiptId,
      target.ingredientId,
    );
    sql.exec(
      "INSERT INTO ingredient_quantity_corrections (sync_write_receipt_id, quantity) VALUES (?, 150)",
      insertReceipt("ingredient", target.ingredientId),
    );
    // 料理が対象の推定を当てて材料を置き換える（前の推定の材料が残る）
    const scheduleId = insertDishSchedule(sql, target.dishId);
    const estimationId = crypto.randomUUID();
    sql.exec(
      "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, ?)",
      estimationId,
      scheduleId,
      Date.now(),
    );
    // 推定の終わりで並べるので、食事の推定より後に終わったことにする
    sql.exec(
      "INSERT INTO estimation_completions (estimation_id, completed_at, result) VALUES (?, ?, 'estimated')",
      estimationId,
      Date.now() + 60_000,
    );
    sql.exec(
      "INSERT INTO dish_estimation_applications (dish_id, estimation_id) VALUES (?, ?)",
      target.dishId,
      estimationId,
    );
    sql.exec(
      "INSERT INTO dish_estimated_quantities (dish_id, estimation_id, quantity, unit) VALUES (?, ?, 1, '杯')",
      target.dishId,
      estimationId,
    );
    const replacingIngredientId = crypto.randomUUID();
    sql.exec(
      `INSERT INTO ingredients (id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish)
       VALUES (?, ?, ?, '豚ロース', 100, 'g', 1, 0)`,
      replacingIngredientId,
      target.dishId,
      estimationId,
    );
    sql.exec(
      "INSERT INTO food_composition_ingredients (ingredient_id, food_number) VALUES (?, '11123')",
      replacingIngredientId,
    );
    sql.exec(
      "INSERT INTO ingredient_nutrients (id, ingredient_id, nutrient, amount_per_basis) VALUES (?, ?, 'energy_kcal', 248)",
      crypto.randomUUID(),
      replacingIngredientId,
    );
    return { replacingIngredientId };
  });

const insertDishSchedule = (sql: Sql, dishId: string): string => {
  const scheduleId = crypto.randomUUID();
  sql.exec(
    "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, ?, '2026-01-01')",
    scheduleId,
    Date.now(),
  );
  sql.exec(
    "INSERT INTO dish_estimation_schedules (estimation_schedule_id, dish_id) VALUES (?, ?)",
    scheduleId,
    dishId,
  );
  return scheduleId;
};
