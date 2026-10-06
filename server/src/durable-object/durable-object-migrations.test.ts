import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { durableObjectMigrations } from "./durable-object-migrations";

type Sql = DurableObjectStorage["sql"];

describe("Durable Object の移行の版 7（料理と材料の表の作り直し）", () => {
  describe("版 6 までの形の食事・推定・料理・材料・削除の印があるとき", () => {
    let account: DurableObjectStub;
    beforeEach(async () => {
      account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      await runInDurableObject(account, async (_, state) => {
        // 起動のときに本物の移行が全部当たっているので、何も当てていない状態に戻してから版 6 まで当てる
        await state.storage.deleteAll();
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 6),
        );
        seedVersion6Rows(state.storage.sql);
        applyDurableObjectMigrations(state.storage, durableObjectMigrations);
      });
    });

    test("外部キーの違反が無いこと", async () => {
      const violations = await runInAccount(account, (sql) =>
        sql.exec("PRAGMA foreign_key_check").toArray(),
      );
      expect(violations).toEqual([]);
    });

    test("料理が残ること", async () => {
      const dishes = await runInAccount(account, (sql) =>
        sql.exec("SELECT id, meal_id, name, position_in_meal FROM dishes ORDER BY id").toArray(),
      );
      expect(dishes).toEqual([
        { id: "dish-1", meal_id: "meal-1", name: "カレー", position_in_meal: 0 },
        { id: "dish-2", meal_id: "meal-1", name: "サラダ", position_in_meal: 1 },
        { id: "dish-3", meal_id: "meal-2", name: "ご飯", position_in_meal: 0 },
      ]);
    });

    test("推定できたが2つある食事では、あとの推定が当てた推定になること", async () => {
      const applications = await runInAccount(account, (sql) =>
        sql
          .exec("SELECT dish_id, estimation_id FROM dish_estimation_applications ORDER BY dish_id")
          .toArray(),
      );
      expect(applications).toEqual([
        { dish_id: "dish-1", estimation_id: "estimation-1b" },
        { dish_id: "dish-2", estimation_id: "estimation-1b" },
        { dish_id: "dish-3", estimation_id: "estimation-2b" },
      ]);
    });

    test("推定の量が、前の料理の量と単位であること", async () => {
      const quantities = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT dish_id, estimation_id, quantity, unit FROM dish_estimated_quantities ORDER BY dish_id",
          )
          .toArray(),
      );
      expect(quantities).toEqual([
        { dish_id: "dish-1", estimation_id: "estimation-1b", quantity: 1.5, unit: "plate" },
        { dish_id: "dish-2", estimation_id: "estimation-1b", quantity: 1, unit: "bowl" },
        { dish_id: "dish-3", estimation_id: "estimation-2b", quantity: 150, unit: "g" },
      ]);
    });

    test("材料が残り、estimation_id が料理の当てた推定であること", async () => {
      const ingredients = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish FROM ingredients ORDER BY id",
          )
          .toArray(),
      );
      expect(ingredients).toEqual([
        {
          id: "ingredient-1",
          dish_id: "dish-1",
          estimation_id: "estimation-1b",
          name: "米",
          quantity: 200,
          unit: "g",
          edible_grams_per_unit: 1,
          position_in_dish: 0,
        },
        {
          id: "ingredient-2",
          dish_id: "dish-1",
          estimation_id: "estimation-1b",
          name: "カレールー",
          quantity: 1,
          unit: "皿分",
          edible_grams_per_unit: 180,
          position_in_dish: 1,
        },
        {
          id: "ingredient-3",
          dish_id: "dish-2",
          estimation_id: "estimation-1b",
          name: "レタス",
          quantity: 50,
          unit: "g",
          edible_grams_per_unit: 1,
          position_in_dish: 0,
        },
        {
          id: "ingredient-4",
          dish_id: "dish-3",
          estimation_id: "estimation-2b",
          name: "米",
          quantity: 150,
          unit: "g",
          edible_grams_per_unit: 1,
          position_in_dish: 0,
        },
      ]);
    });

    test("材料の栄養の値と出どころのサブセットが残ること", async () => {
      const rows = await runInAccount(account, (sql) => ({
        foodComposition: sql
          .exec("SELECT ingredient_id, food_number FROM food_composition_ingredients")
          .toArray(),
        nutritionLabel: sql
          .exec("SELECT ingredient_id, label_basis_grams FROM nutrition_label_ingredients")
          .toArray(),
        nutrients: sql
          .exec(
            "SELECT id, ingredient_id, nutrient, amount_per_basis FROM ingredient_nutrients ORDER BY id",
          )
          .toArray(),
      }));
      expect(rows).toEqual({
        foodComposition: [{ ingredient_id: "ingredient-1", food_number: "01088" }],
        nutritionLabel: [{ ingredient_id: "ingredient-2", label_basis_grams: 180 }],
        nutrients: [
          {
            id: "nutrient-1",
            ingredient_id: "ingredient-1",
            nutrient: "energy_kcal",
            amount_per_basis: 156,
          },
          {
            id: "nutrient-2",
            ingredient_id: "ingredient-2",
            nutrient: "energy_kcal",
            amount_per_basis: 120,
          },
        ],
      });
    });

    test("料理と材料の削除の印が、消した書き込みの控えつきで残ること", async () => {
      const deletions = await runInAccount(account, (sql) => ({
        dishes: sql.exec("SELECT dish_id, sync_write_receipt_id FROM dish_deletions").toArray(),
        ingredients: sql
          .exec("SELECT ingredient_id, sync_write_receipt_id FROM ingredient_deletions")
          .toArray(),
      }));
      expect(deletions).toEqual({
        dishes: [{ dish_id: "dish-gone", sync_write_receipt_id: "receipt-1" }],
        ingredients: [{ ingredient_id: "ingredient-gone", sync_write_receipt_id: "receipt-1" }],
      });
    });

    test("料理の版が 1 であること", async () => {
      const dish = await runInDurableObject(account, (_, state) =>
        createDishStore(drizzle(state.storage)).find("dish-1"),
      );
      expect(dish).toEqual({
        id: "dish-1",
        mealId: "meal-1",
        name: "カレー",
        quantity: 1.5,
        unit: "plate",
        positionInMeal: 0,
        version: 1,
      });
    });

    test("作り直した表と足した表の索引がそろっていること", async () => {
      const indexes = await runInAccount(account, (sql) =>
        sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'index' AND name IN ('dishes_meal_id', 'ingredients_application', 'ingredients_dish_id', 'ingredient_nutrients_nutrient', 'meal_eaten_at_corrections_eaten_at', 'dish_quantity_correction_ingredients_ingredient_id', 'dish_estimation_schedules_dish_id') ORDER BY name",
          )
          .toArray()
          .map(({ name }) => name),
      );
      expect(indexes).toEqual([
        "dish_estimation_schedules_dish_id",
        "dish_quantity_correction_ingredients_ingredient_id",
        "dishes_meal_id",
        "ingredient_nutrients_nutrient",
        "ingredients_application",
        "meal_eaten_at_corrections_eaten_at",
      ]);
    });

    test("写しの表と、控えとのつなぎの削除の印の表が残らないこと", async () => {
      const tables = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND (name LIKE 'migration\\_%' ESCAPE '\\' OR name LIKE 'sync\\_write\\_%\\_deletions' ESCAPE '\\')",
          )
          .toArray(),
      );
      expect(tables).toEqual([]);
    });

    test("移行のあとは、材料の残る料理を消せないこと", async () => {
      await expect(
        runInAccount(account, (sql) => {
          sql.exec("DELETE FROM dishes WHERE id = 'dish-1'");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });

    test("移行のあとは、当てた推定に属さない材料を置けないこと", async () => {
      await expect(
        runInAccount(account, (sql) => {
          sql.exec(
            "INSERT INTO ingredients (id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES ('ingredient-5', 'dish-1', 'estimation-1a', '米', 100, 'g', 1, 2)",
          );
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });
});

const runInAccount = <T>(account: DurableObjectStub, run: (sql: Sql) => T): Promise<T> =>
  runInDurableObject(account, (_, state) => run(state.storage.sql));

// 食事3つ（推定できたが2つの食事、推定できなかったあとに推定できた食事、料理なしの食事）、推定5つ、料理3つ、材料4つ、
// 栄養の値と出どころのサブセット、#188 の形の料理と材料の削除の印（控えとのつなぎつき）
const seedVersion6Rows = (sql: Sql) => {
  for (const mealId of ["meal-1", "meal-2", "meal-3"]) {
    sql.exec(
      "INSERT INTO meals (id, eaten_at, eaten_at_utc_offset_seconds, sent_at, sent_time_zone, entry_method) VALUES (?, 0, 32400, 0, 'Asia/Tokyo', 'captured')",
      mealId,
    );
  }
  const estimations = [
    { id: "estimation-1a", mealId: "meal-1", startedAt: 1000, end: "estimated", endedAt: 2000 },
    { id: "estimation-1b", mealId: "meal-1", startedAt: 3000, end: "estimated", endedAt: 4000 },
    { id: "estimation-2a", mealId: "meal-2", startedAt: 1000, end: "abandoned", endedAt: 2000 },
    { id: "estimation-2b", mealId: "meal-2", startedAt: 3000, end: "estimated", endedAt: 4000 },
    { id: "estimation-3", mealId: "meal-3", startedAt: 1000, end: "no_dishes", endedAt: 2000 },
  ];
  for (const { id, mealId, startedAt, end, endedAt } of estimations) {
    const scheduleId = `schedule-of-${id}`;
    sql.exec(
      "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, ?, '2026-01-01')",
      scheduleId,
      startedAt,
    );
    sql.exec(
      "INSERT INTO meal_estimation_schedules (estimation_schedule_id, meal_id) VALUES (?, ?)",
      scheduleId,
      mealId,
    );
    sql.exec(
      "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, ?)",
      id,
      scheduleId,
      startedAt,
    );
    if (end === "abandoned") {
      sql.exec(
        "INSERT INTO estimation_abandonments (estimation_id, abandoned_at) VALUES (?, ?)",
        id,
        endedAt,
      );
    } else {
      sql.exec(
        "INSERT INTO estimation_completions (estimation_id, completed_at, result) VALUES (?, ?, ?)",
        id,
        endedAt,
        end,
      );
    }
  }
  const dishes = [
    { id: "dish-1", mealId: "meal-1", name: "カレー", quantity: 1.5, unit: "plate", position: 0 },
    { id: "dish-2", mealId: "meal-1", name: "サラダ", quantity: 1, unit: "bowl", position: 1 },
    { id: "dish-3", mealId: "meal-2", name: "ご飯", quantity: 150, unit: "g", position: 0 },
  ];
  for (const { id, mealId, name, quantity, unit, position } of dishes) {
    sql.exec(
      "INSERT INTO dishes (id, meal_id, name, quantity, unit, position_in_meal, version) VALUES (?, ?, ?, ?, ?, ?, 1)",
      id,
      mealId,
      name,
      quantity,
      unit,
      position,
    );
  }
  const ingredients = [
    {
      id: "ingredient-1",
      dishId: "dish-1",
      name: "米",
      quantity: 200,
      unit: "g",
      grams: 1,
      position: 0,
    },
    {
      id: "ingredient-2",
      dishId: "dish-1",
      name: "カレールー",
      quantity: 1,
      unit: "皿分",
      grams: 180,
      position: 1,
    },
    {
      id: "ingredient-3",
      dishId: "dish-2",
      name: "レタス",
      quantity: 50,
      unit: "g",
      grams: 1,
      position: 0,
    },
    {
      id: "ingredient-4",
      dishId: "dish-3",
      name: "米",
      quantity: 150,
      unit: "g",
      grams: 1,
      position: 0,
    },
  ];
  for (const { id, dishId, name, quantity, unit, grams, position } of ingredients) {
    sql.exec(
      "INSERT INTO ingredients (id, dish_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES (?, ?, ?, ?, ?, ?, ?)",
      id,
      dishId,
      name,
      quantity,
      unit,
      grams,
      position,
    );
  }
  sql.exec(
    "INSERT INTO food_composition_ingredients (ingredient_id, food_number) VALUES ('ingredient-1', '01088')",
  );
  sql.exec(
    "INSERT INTO nutrition_label_ingredients (ingredient_id, label_basis_grams) VALUES ('ingredient-2', 180)",
  );
  sql.exec(
    "INSERT INTO ingredient_nutrients (id, ingredient_id, nutrient, amount_per_basis) VALUES ('nutrient-1', 'ingredient-1', 'energy_kcal', 156), ('nutrient-2', 'ingredient-2', 'energy_kcal', 120)",
  );
  sql.exec(
    "INSERT INTO sync_request_logs (id, device_id, received_at, time_zone, app_version, os_version, pending_write_count, pending_photo_count) VALUES ('request-1', 'device-1', 0, 'Asia/Tokyo', '1.0.0', '26.0', 1, 0)",
  );
  sql.exec(
    "INSERT INTO sync_push_logs (sync_request_log_id, is_final_batch) VALUES ('request-1', 1)",
  );
  sql.exec(
    "INSERT INTO sync_write_receipts (id, sync_request_log_id, position_in_request, kind, record_type, record_id, result) VALUES ('receipt-1', 'request-1', 0, 'delete', 'meal', 'meal-gone', 'applied')",
  );
  sql.exec("INSERT INTO dish_deletions (dish_id) VALUES ('dish-gone')");
  sql.exec(
    "INSERT INTO sync_write_dish_deletions (dish_id, sync_write_receipt_id) VALUES ('dish-gone', 'receipt-1')",
  );
  sql.exec("INSERT INTO ingredient_deletions (ingredient_id) VALUES ('ingredient-gone')");
  sql.exec(
    "INSERT INTO sync_write_ingredient_deletions (ingredient_id, sync_write_receipt_id) VALUES ('ingredient-gone', 'receipt-1')",
  );
};
