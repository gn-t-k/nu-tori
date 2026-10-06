import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

type Sql = DurableObjectStorage["sql"];

// まだ書き込みの口が無い直し（推定し直し、予定の取り消し）を、DB に直に書く。
// 「消したら中身が残らない」の前提に使う。書き込みの口を足すチケットで、その分を本物の書き込みに置き換える
// （#332 の「テストの決定」）。置き換えの済んだ分（時刻・名前・料理の量・材料の量の修正）は、ここから消した。
// 取り消しは、名前を直した本物の書き込み（cancellingRenameWriteId。控えの ID は書き込みの ID）が取り消したことにする
export const seedNotYetWritableEdits = (
  accountId: string,
  target: { dishId: string; cancellingRenameWriteId: string },
): Promise<{ replacingIngredientId: string }> =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const { sql } = state.storage;
    // 1回目の名前の修正で待った予定を、2回目の名前の修正で取り消す
    const cancelledScheduleId = insertDishSchedule(sql, target.dishId);
    sql.exec(
      "INSERT INTO estimation_schedule_cancellations (estimation_schedule_id, sync_write_receipt_id) VALUES (?, ?)",
      cancelledScheduleId,
      target.cancellingRenameWriteId,
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
