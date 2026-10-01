import { env, runInDurableObject } from "cloudflare:test";
import { describe, expect, test } from "vitest";

// Durable Object の SQLite の外部キーは、黙って効かなくなっても気づけるよう、食事・推定・料理・材料の表で確かめる
type Sql = DurableObjectStorage["sql"];

describe("食事・推定・料理・材料の表の外部キー", () => {
  describe("栄養の値と出どころのサブセットを持つ材料があるとき", () => {
    test("材料を消すと、栄養の値と出どころのサブセットも消えること", async () => {
      const counts = await runInAccount((sql) => {
        seedIngredientWithNutrients(sql);
        sql.exec("DELETE FROM ingredients WHERE id = 'ingredient-1'");
        return {
          ingredients: countRows(sql, "ingredients"),
          nutrients: countRows(sql, "ingredient_nutrients"),
          foodComposition: countRows(sql, "food_composition_ingredients"),
          nutritionLabel: countRows(sql, "nutrition_label_ingredients"),
        };
      });
      expect(counts).toEqual({
        ingredients: 0,
        nutrients: 0,
        foodComposition: 0,
        nutritionLabel: 0,
      });
    });

    test("材料の残る料理は消せないこと", async () => {
      await expect(
        runInAccount((sql) => {
          seedIngredientWithNutrients(sql);
          sql.exec("DELETE FROM dishes WHERE id = 'dish-1'");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });

    test("料理の残る食事は消せないこと", async () => {
      await expect(
        runInAccount((sql) => {
          seedIngredientWithNutrients(sql);
          sql.exec("DELETE FROM meals WHERE id = 'meal-1'");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });

  describe("推定の予定の対象の食事があるとき", () => {
    test("食事を消すと、予定とのつなぎが消え、予定・推定・試みが残ること", async () => {
      const counts = await runInAccount((sql) => {
        insertMeal(sql, "meal-1");
        sql.exec(
          "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES ('schedule-1', 0, '2026-01-01')",
        );
        sql.exec(
          "INSERT INTO meal_estimation_schedules (estimation_schedule_id, meal_id) VALUES ('schedule-1', 'meal-1')",
        );
        sql.exec(
          "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES ('estimation-1', 'schedule-1', 0)",
        );
        sql.exec(
          "INSERT INTO estimation_attempts (id, estimation_id, attempted_at) VALUES ('attempt-1', 'estimation-1', 0)",
        );
        sql.exec("DELETE FROM meals WHERE id = 'meal-1'");
        return {
          meals: countRows(sql, "meals"),
          links: countRows(sql, "meal_estimation_schedules"),
          schedules: countRows(sql, "estimation_schedules"),
          estimations: countRows(sql, "estimations"),
          attempts: countRows(sql, "estimation_attempts"),
        };
      });
      expect(counts).toEqual({ meals: 0, links: 0, schedules: 1, estimations: 1, attempts: 1 });
    });
  });

  describe("写真の宣言のある食事があるとき", () => {
    test("写真の宣言の残る食事は消せないこと", async () => {
      await expect(
        runInAccount((sql) => {
          insertMeal(sql, "meal-1");
          sql.exec(
            "INSERT INTO meal_photos (id, meal_id, position_in_meal) VALUES ('photo-1', 'meal-1', 0)",
          );
          sql.exec("DELETE FROM meals WHERE id = 'meal-1'");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });

  describe("食事が無いとき", () => {
    test("食事の無い料理は INSERT できないこと", async () => {
      await expect(
        runInAccount((sql) => {
          insertDish(sql, "dish-1", "meal-missing");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });
});

const runInAccount = <T>(run: (sql: Sql) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_, state) =>
    run(state.storage.sql),
  );

const countRows = (sql: Sql, table: string): number =>
  sql.exec<{ count: number }>(`SELECT count(*) AS count FROM ${table}`).one().count;

const seedIngredientWithNutrients = (sql: Sql) => {
  insertMeal(sql, "meal-1");
  insertDish(sql, "dish-1", "meal-1");
  sql.exec(
    "INSERT INTO ingredients (id, dish_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES ('ingredient-1', 'dish-1', '米', 150, 'g', 1, 0)",
  );
  sql.exec(
    "INSERT INTO food_composition_ingredients (ingredient_id, food_number) VALUES ('ingredient-1', '01083')",
  );
  sql.exec(
    "INSERT INTO nutrition_label_ingredients (ingredient_id, label_basis_grams) VALUES ('ingredient-1', 100)",
  );
  sql.exec(
    "INSERT INTO ingredient_nutrients (id, ingredient_id, nutrient, amount_per_basis) VALUES ('nutrient-1', 'ingredient-1', 'energy_kcal', 156)",
  );
};

const insertMeal = (sql: Sql, id: string) => {
  sql.exec(
    "INSERT INTO meals (id, eaten_at, eaten_at_utc_offset_seconds, sent_at, sent_time_zone, entry_method) VALUES (?, 0, 32400, 0, 'Asia/Tokyo', 'captured')",
    id,
  );
};

const insertDish = (sql: Sql, id: string, mealId: string) => {
  sql.exec(
    "INSERT INTO dishes (id, meal_id, name, quantity, unit, position_in_meal, version) VALUES (?, ?, 'カレー', 1, 'plate', 0, 1)",
    id,
    mealId,
  );
};
