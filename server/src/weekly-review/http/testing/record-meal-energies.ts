import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 渡した日（YYYY-MM-DD）ごとに、日本時間の正午に食べた、推定の済んだ食事を1つ置く。
// 料理1つ・材料1つ（栄養成分表示の 100 g あたり kcal を 100 g）で、その日の食べた量が kcal になる。
// 推定はアラームで進めると時計と提供元の準備が要るので、推定のあとの行を直に置く
export const recordMealEnergies = (
  accountId: string,
  calendarDays: readonly string[],
  kcal: number,
): Promise<void> =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const { sql } = state.storage;
    for (const calendarDay of calendarDays) {
      const [mealId, dishId, scheduleId, estimationId, ingredientId, nutrientId] = Array.from(
        { length: 6 },
        () => generateRecordId(),
      );
      const eatenAt = Date.parse(`${calendarDay}T03:00:00Z`);
      sql.exec(
        "INSERT INTO meals (id, eaten_at, eaten_at_utc_offset_seconds, sent_at, sent_time_zone, entry_method) VALUES (?, ?, 32400, ?, 'Asia/Tokyo', 'captured')",
        mealId,
        eatenAt,
        eatenAt,
      );
      sql.exec(
        "INSERT INTO dishes (id, meal_id, name, position_in_meal) VALUES (?, ?, '定食', 0)",
        dishId,
        mealId,
      );
      sql.exec(
        "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, ?, ?)",
        scheduleId,
        eatenAt,
        calendarDay,
      );
      sql.exec(
        "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, ?)",
        estimationId,
        scheduleId,
        eatenAt,
      );
      sql.exec(
        "INSERT INTO dish_estimation_applications (dish_id, estimation_id) VALUES (?, ?)",
        dishId,
        estimationId,
      );
      sql.exec(
        "INSERT INTO ingredients (id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES (?, ?, ?, 'ご飯', 100, 'g', 1, 0)",
        ingredientId,
        dishId,
        estimationId,
      );
      sql.exec(
        "INSERT INTO nutrition_label_ingredients (ingredient_id, label_basis_grams) VALUES (?, 100)",
        ingredientId,
      );
      sql.exec(
        "INSERT INTO ingredient_nutrients (id, ingredient_id, nutrient, amount_per_basis) VALUES (?, ?, 'energy_kcal', ?)",
        nutrientId,
        ingredientId,
        kcal,
      );
    }
  });
