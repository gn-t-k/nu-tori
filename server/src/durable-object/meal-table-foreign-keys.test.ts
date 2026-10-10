import { env, runInDurableObject } from "cloudflare:test";
import { beforeEach, describe, expect, test } from "vitest";

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

  describe("当てた推定と推定の量、料理が対象の予定のつなぎと取り消しを持つ料理があるとき", () => {
    let account: Account;
    beforeEach(async () => {
      account = createAccount();
      await runIn(account, (sql) => {
        seedDishWithEstimation(sql);
        insertReceipt(sql, "receipt-1", "dish", "dish-1");
        sql.exec(
          "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES ('schedule-2', 0, '2026-01-01')",
        );
        sql.exec(
          "INSERT INTO dish_estimation_schedules (estimation_schedule_id, dish_id) VALUES ('schedule-1', 'dish-1'), ('schedule-2', 'dish-1')",
        );
        sql.exec(
          "INSERT INTO estimation_schedule_cancellations (estimation_schedule_id, sync_write_receipt_id) VALUES ('schedule-2', 'receipt-1')",
        );
      });
    });

    test("料理を消すと、当てた推定・推定の量・つなぎ・取り消しが消え、予定と推定が残ること", async () => {
      const counts = await runIn(account, (sql) => {
        sql.exec("DELETE FROM dishes WHERE id = 'dish-1'");
        return {
          dishes: countRows(sql, "dishes"),
          applications: countRows(sql, "dish_estimation_applications"),
          quantities: countRows(sql, "dish_estimated_quantities"),
          links: countRows(sql, "dish_estimation_schedules"),
          cancellations: countRows(sql, "estimation_schedule_cancellations"),
          schedules: countRows(sql, "estimation_schedules"),
          estimations: countRows(sql, "estimations"),
        };
      });
      expect(counts).toEqual({
        dishes: 0,
        applications: 0,
        quantities: 0,
        links: 0,
        cancellations: 0,
        schedules: 2,
        estimations: 1,
      });
    });
  });

  describe("当てた推定が無いとき", () => {
    let account: Account;
    beforeEach(async () => {
      account = createAccount();
      await runIn(account, (sql) => {
        insertMeal(sql, "meal-1");
        insertDish(sql, "dish-1", "meal-1");
        insertEstimation(sql, "schedule-1", "estimation-1");
      });
    });

    test("当てた推定に属さない材料は INSERT できないこと", async () => {
      await expect(
        runIn(account, (sql) => {
          insertIngredient(sql, "ingredient-1", "dish-1", "estimation-1");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });

  describe("料理の量の修正と、その比例の明細があるとき", () => {
    let account: Account;
    beforeEach(async () => {
      account = createAccount();
      await runIn(account, seedQuantityCorrectionWithProportion);
    });

    test("料理の量の修正を消すと、比例の明細が消えること", async () => {
      const counts = await runIn(account, (sql) => {
        sql.exec("DELETE FROM dish_quantity_corrections WHERE sync_write_receipt_id = 'receipt-1'");
        return {
          ingredients: countRows(sql, "ingredients"),
          proportions: countRows(sql, "dish_quantity_correction_ingredients"),
        };
      });
      expect(counts).toEqual({ ingredients: 1, proportions: 0 });
    });

    test("材料を消すと、比例の明細と栄養の値が消えること", async () => {
      const counts = await runIn(account, (sql) => {
        sql.exec("DELETE FROM ingredients WHERE id = 'ingredient-1'");
        return {
          corrections: countRows(sql, "dish_quantity_corrections"),
          proportions: countRows(sql, "dish_quantity_correction_ingredients"),
          nutrients: countRows(sql, "ingredient_nutrients"),
        };
      });
      expect(counts).toEqual({ corrections: 1, proportions: 0, nutrients: 0 });
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

  describe("文章の食事に、推定した時刻と推定が作った食事があるとき", () => {
    test("食事を消すと、文章の食事のサブセット・推定した時刻・推定が作った食事が消え、送った文章と推定が残ること", async () => {
      const counts = await runInAccount((sql) => {
        sql.exec(
          "INSERT INTO sent_texts (id, body, sent_at, sent_time_zone) VALUES ('sent-text-1', '朝はパン、昼はうどん', 0, 'Asia/Tokyo')",
        );
        insertMeal(sql, "meal-1");
        insertMeal(sql, "meal-2");
        sql.exec(
          "INSERT INTO sent_text_meals (meal_id, sent_text_id) VALUES ('meal-1', 'sent-text-1'), ('meal-2', 'sent-text-1')",
        );
        insertEstimation(sql, "schedule-1", "estimation-1");
        sql.exec(
          "INSERT INTO meal_eaten_at_estimations (meal_id, estimation_id, eaten_at) VALUES ('meal-1', 'estimation-1', 0)",
        );
        sql.exec(
          "INSERT INTO estimation_created_meals (meal_id, estimation_id) VALUES ('meal-2', 'estimation-1')",
        );
        sql.exec("DELETE FROM meals");
        return {
          sentTextMeals: countRows(sql, "sent_text_meals"),
          eatenAts: countRows(sql, "meal_eaten_at_estimations"),
          createdMeals: countRows(sql, "estimation_created_meals"),
          sentTexts: countRows(sql, "sent_texts"),
          estimations: countRows(sql, "estimations"),
          violations: sql.exec("PRAGMA foreign_key_check").toArray().length,
        };
      });
      expect(counts).toEqual({
        sentTextMeals: 0,
        eatenAts: 0,
        createdMeals: 0,
        sentTexts: 1,
        estimations: 1,
        violations: 0,
      });
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

// 準備と確かめる操作を、同じアカウントの Durable Object で別々に動かす
type Account = ReturnType<typeof createAccount>;

const createAccount = () => env.ACCOUNT.get(env.ACCOUNT.newUniqueId());

const runIn = <T>(account: Account, run: (sql: Sql) => T): Promise<T> =>
  runInDurableObject(account, (_, state) => run(state.storage.sql));

const countRows = (sql: Sql, table: string): number =>
  sql.exec<{ count: number }>(`SELECT count(*) AS count FROM ${table}`).one().count;

// 食事・料理・当てた推定（推定の量つき）。推定の予定は schedule-1、推定は estimation-1
const seedDishWithEstimation = (sql: Sql) => {
  insertMeal(sql, "meal-1");
  insertDish(sql, "dish-1", "meal-1");
  insertEstimation(sql, "schedule-1", "estimation-1");
  sql.exec(
    "INSERT INTO dish_estimation_applications (dish_id, estimation_id) VALUES ('dish-1', 'estimation-1')",
  );
  sql.exec(
    "INSERT INTO dish_estimated_quantities (dish_id, estimation_id, quantity, unit) VALUES ('dish-1', 'estimation-1', 1, 'plate')",
  );
};

const seedIngredientWithNutrients = (sql: Sql) => {
  seedDishWithEstimation(sql);
  insertIngredient(sql, "ingredient-1", "dish-1", "estimation-1");
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

const seedQuantityCorrectionWithProportion = (sql: Sql) => {
  seedIngredientWithNutrients(sql);
  insertReceipt(sql, "receipt-1", "dish", "dish-1");
  sql.exec(
    "INSERT INTO dish_quantity_corrections (sync_write_receipt_id, quantity) VALUES ('receipt-1', 2)",
  );
  sql.exec(
    "INSERT INTO dish_quantity_correction_ingredients (sync_write_receipt_id, ingredient_id, quantity) VALUES ('receipt-1', 'ingredient-1', 300)",
  );
};

const insertDish = (sql: Sql, id: string, mealId: string) => {
  sql.exec(
    "INSERT INTO dishes (id, meal_id, name, position_in_meal) VALUES (?, ?, 'カレー', 0)",
    id,
    mealId,
  );
};

const insertEstimation = (sql: Sql, scheduleId: string, estimationId: string) => {
  sql.exec(
    "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, 0, '2026-01-01')",
    scheduleId,
  );
  sql.exec(
    "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, 0)",
    estimationId,
    scheduleId,
  );
};

const insertIngredient = (sql: Sql, id: string, dishId: string, estimationId: string) => {
  sql.exec(
    "INSERT INTO ingredients (id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES (?, ?, ?, '米', 150, 'g', 1, 0)",
    id,
    dishId,
    estimationId,
  );
};

const insertReceipt = (sql: Sql, id: string, recordType: string, recordId: string) => {
  sql.exec(
    "INSERT OR IGNORE INTO sync_request_logs (id, device_id, received_at, time_zone, app_version, os_version, pending_write_count, pending_photo_count) VALUES ('request-1', 'device-1', 0, 'Asia/Tokyo', '1.0.0', '26.0', 1, 0)",
  );
  sql.exec(
    "INSERT OR IGNORE INTO sync_push_logs (sync_request_log_id, is_final_batch) VALUES ('request-1', 1)",
  );
  sql.exec(
    "INSERT INTO sync_write_receipts (id, sync_request_log_id, position_in_request, kind, record_type, record_id, result) VALUES (?, 'request-1', (SELECT count(*) FROM sync_write_receipts), 'update', ?, ?, 'applied')",
    id,
    recordType,
    recordId,
  );
};
