import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { recordIdSchema } from "../domain/record-id";
import { createDishStore } from "../dish/durable-object/create-dish-store";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { durableObjectMigrations } from "./durable-object-migrations";

type Sql = DurableObjectStorage["sql"];

// 料理の置き場で読む料理と、その食事。ほかの行の ID は版 6 までの形のまま文字列で書く。
// 料理の ID は、ORDER BY id で "dish-2" より前に並ぶ値にする
const dish1 = recordIdSchema.parse("d1000000-0000-4000-8000-000000000000");
const meal1 = recordIdSchema.parse("a1000000-0000-4000-8000-000000000000");

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
        { id: dish1, meal_id: meal1, name: "カレー", position_in_meal: 0 },
        { id: "dish-2", meal_id: meal1, name: "サラダ", position_in_meal: 1 },
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
        { dish_id: dish1, estimation_id: "estimation-1b" },
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
        { dish_id: dish1, estimation_id: "estimation-1b", quantity: 1.5, unit: "plate" },
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
          dish_id: dish1,
          estimation_id: "estimation-1b",
          name: "米",
          quantity: 200,
          unit: "g",
          edible_grams_per_unit: 1,
          position_in_dish: 0,
        },
        {
          id: "ingredient-2",
          dish_id: dish1,
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
        createDishStore(drizzle(state.storage)).find(dish1),
      );
      expect(dish).toEqual({
        id: dish1,
        mealId: meal1,
        name: "カレー",
        quantity: { value: 1.5, unit: "plate", source: "estimated" },
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
          sql.exec("DELETE FROM dishes WHERE id = ?", dish1);
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });

    test("移行のあとは、当てた推定に属さない材料を置けないこと", async () => {
      await expect(
        runInAccount(account, (sql) => {
          sql.exec(
            "INSERT INTO ingredients (id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish) VALUES ('ingredient-5', ?, 'estimation-1a', '米', 100, 'g', 1, 2)",
            dish1,
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
  for (const mealId of [meal1, "meal-2", "meal-3"]) {
    sql.exec(
      "INSERT INTO meals (id, eaten_at, eaten_at_utc_offset_seconds, sent_at, sent_time_zone, entry_method) VALUES (?, 0, 32400, 0, 'Asia/Tokyo', 'captured')",
      mealId,
    );
  }
  const estimations = [
    { id: "estimation-1a", mealId: meal1, startedAt: 1000, end: "estimated", endedAt: 2000 },
    { id: "estimation-1b", mealId: meal1, startedAt: 3000, end: "estimated", endedAt: 4000 },
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
    { id: dish1, mealId: meal1, name: "カレー", quantity: 1.5, unit: "plate", position: 0 },
    { id: "dish-2", mealId: meal1, name: "サラダ", quantity: 1, unit: "bowl", position: 1 },
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
      dishId: dish1,
      name: "米",
      quantity: 200,
      unit: "g",
      grams: 1,
      position: 0,
    },
    {
      id: "ingredient-2",
      dishId: dish1,
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

describe("Durable Object の移行の版 8（文章と会話の表）", () => {
  describe("版 7 までの形の食事・推定・料理・材料・控えがあるとき", () => {
    let account: DurableObjectStub;
    let rowsBefore: Record<string, unknown[]>;
    beforeEach(async () => {
      account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      rowsBefore = await runInDurableObject(account, async (_, state) => {
        await state.storage.deleteAll();
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 6),
        );
        seedVersion6Rows(state.storage.sql);
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 7),
        );
        const rows = readAllRows(state.storage.sql);
        applyDurableObjectMigrations(state.storage, durableObjectMigrations);
        return rows;
      });
    });

    test("文章と会話の 20 の表ができること", async () => {
      const tables = await runInAccount(account, (sql) =>
        sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name IN ('sent_texts', 'sent_text_classifications', 'sent_text_conversation_resends', 'sent_text_resends', 'conversation_resend_meal_deletions', 'sent_text_meals', 'estimation_created_meals', 'meal_eaten_at_estimations', 'reply_requests', 'classification_reply_requests', 'resend_reply_requests', 'conversation_resend_reply_requests', 'reply_request_halts', 'reply_generations', 'reply_generation_attempts', 'reply_generation_attempt_results', 'reply_generation_attempt_errors', 'reply_generation_abandonments', 'ai_utterances', 'ai_utterance_meals') ORDER BY name",
          )
          .toArray()
          .map(({ name }) => name),
      );
      expect(tables).toEqual([
        "ai_utterance_meals",
        "ai_utterances",
        "classification_reply_requests",
        "conversation_resend_meal_deletions",
        "conversation_resend_reply_requests",
        "estimation_created_meals",
        "meal_eaten_at_estimations",
        "reply_generation_abandonments",
        "reply_generation_attempt_errors",
        "reply_generation_attempt_results",
        "reply_generation_attempts",
        "reply_generations",
        "reply_request_halts",
        "reply_requests",
        "resend_reply_requests",
        "sent_text_classifications",
        "sent_text_conversation_resends",
        "sent_text_meals",
        "sent_text_resends",
        "sent_texts",
      ]);
    });

    test("文章と会話の 6 つの索引が、それぞれの表にできること", async () => {
      const indexes = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT name, tbl_name FROM sqlite_schema WHERE type = 'index' AND name IN ('sent_texts_sent_at', 'sent_text_meals_sent_text_id', 'meal_eaten_at_estimations_eaten_at', 'reply_requests_sent_text_id', 'reply_requests_counted_on', 'reply_generation_attempts_reply_generation_id') ORDER BY name",
          )
          .toArray(),
      );
      expect(indexes).toEqual([
        { name: "meal_eaten_at_estimations_eaten_at", tbl_name: "meal_eaten_at_estimations" },
        {
          name: "reply_generation_attempts_reply_generation_id",
          tbl_name: "reply_generation_attempts",
        },
        { name: "reply_requests_counted_on", tbl_name: "reply_requests" },
        { name: "reply_requests_sent_text_id", tbl_name: "reply_requests" },
        { name: "sent_text_meals_sent_text_id", tbl_name: "sent_text_meals" },
        { name: "sent_texts_sent_at", tbl_name: "sent_texts" },
      ]);
    });

    test("既存の表の行が変わらないこと", async () => {
      const rowsAfter = await runInAccount(account, readAllRows);
      expect(
        Object.fromEntries(Object.keys(rowsBefore).map((name) => [name, rowsAfter[name]])),
      ).toEqual(rowsBefore);
    });

    test("外部キーの違反が無いこと", async () => {
      const violations = await runInAccount(account, (sql) =>
        sql.exec("PRAGMA foreign_key_check").toArray(),
      );
      expect(violations).toEqual([]);
    });
  });
});

describe("Durable Object の移行の版 9（目標・推定消費カロリー・1日の目安の表）", () => {
  describe("版 8 までの形の食事・推定・料理・材料・控えがあるとき", () => {
    let account: DurableObjectStub;
    let rowsBefore: Record<string, unknown[]>;
    beforeEach(async () => {
      account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      rowsBefore = await runInDurableObject(account, async (_, state) => {
        await state.storage.deleteAll();
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 6),
        );
        seedVersion6Rows(state.storage.sql);
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 8),
        );
        const rows = readAllRows(state.storage.sql);
        applyDurableObjectMigrations(state.storage, durableObjectMigrations);
        return rows;
      });
    });

    test("目標・推定消費カロリー・1日の目安の 8 つの表ができること", async () => {
      const tables = await runInAccount(account, (sql) =>
        sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name IN ('goals', 'weight_change_goals', 'goal_closures', 'goal_decision_receipts', 'expenditure_estimates', 'initial_expenditure_estimates', 'daily_guides', 'daily_guide_limit_hits') ORDER BY name",
          )
          .toArray()
          .map(({ name }) => name),
      );
      expect(tables).toEqual([
        "daily_guide_limit_hits",
        "daily_guides",
        "expenditure_estimates",
        "goal_closures",
        "goal_decision_receipts",
        "goals",
        "initial_expenditure_estimates",
        "weight_change_goals",
      ]);
    });

    test("3 つの一意の索引が、それぞれの表にできること", async () => {
      const indexes = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT s.name AS name, s.tbl_name AS tbl_name, l.\"unique\" AS is_unique FROM sqlite_schema AS s JOIN pragma_index_list(s.tbl_name) AS l ON l.name = s.name WHERE s.type = 'index' AND s.name IN ('goal_closures_next_goal_id', 'goal_decision_receipts_goal_id', 'daily_guides_goal_id') ORDER BY s.name",
          )
          .toArray(),
      );
      expect(indexes).toEqual([
        { name: "daily_guides_goal_id", tbl_name: "daily_guides", is_unique: 1 },
        { name: "goal_closures_next_goal_id", tbl_name: "goal_closures", is_unique: 1 },
        {
          name: "goal_decision_receipts_goal_id",
          tbl_name: "goal_decision_receipts",
          is_unique: 1,
        },
      ]);
    });

    test("既存の表の行が変わらないこと", async () => {
      const rowsAfter = await runInAccount(account, readAllRows);
      expect(
        Object.fromEntries(Object.keys(rowsBefore).map((name) => [name, rowsAfter[name]])),
      ).toEqual(rowsBefore);
    });

    test("外部キーの違反が無いこと", async () => {
      const violations = await runInAccount(account, (sql) =>
        sql.exec("PRAGMA foreign_key_check").toArray(),
      );
      expect(violations).toEqual([]);
    });
  });
});

// 版 9 までの形の目標・減量のサブセット・閉じた目標・推定・1日の目安。版 10 の表が指す親の行
const seedVersion9GoalRows = (sql: Sql) => {
  sql.exec(
    "INSERT INTO goals (id, started_on, starting_weight_trend_kg, target_weight_kg, decided_at, time_zone) VALUES ('goal-1', '2026-09-01', 70, 65, 0, 'Asia/Tokyo'), ('goal-2', '2026-09-08', 69.5, 69.5, 1, 'Asia/Tokyo')",
  );
  sql.exec(
    "INSERT INTO weight_change_goals (goal_id, deadline_on, pace_plan) VALUES ('goal-1', '2026-12-31', 'standard')",
  );
  sql.exec("INSERT INTO goal_closures (goal_id, next_goal_id) VALUES ('goal-1', 'goal-2')");
  sql.exec(
    "INSERT INTO expenditure_estimates (id, effective_on, expenditure_kcal, estimated_at) VALUES ('estimate-1', '2026-09-01', 2200, 0)",
  );
  sql.exec(
    "INSERT INTO initial_expenditure_estimates (expenditure_estimate_id, source) VALUES ('estimate-1', 'formula')",
  );
  sql.exec(
    "INSERT INTO daily_guides (id, goal_id, expenditure_estimate_id, effective_on, energy_kcal, protein_g, fat_g, carbohydrate_g) VALUES ('guide-1', 'goal-1', 'estimate-1', '2026-09-01', 1800, 100, 50, 230), ('guide-2', 'goal-2', 'estimate-1', '2026-09-08', 2200, 100, 60, 300)",
  );
};

describe("Durable Object の移行の版 10（週の見直しと目標の経過の表）", () => {
  describe("版 9 までの形の食事・料理・材料・控え・目標・推定・1日の目安があるとき", () => {
    let account: DurableObjectStub;
    let rowsBefore: Record<string, unknown[]>;
    beforeEach(async () => {
      account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      rowsBefore = await runInDurableObject(account, async (_, state) => {
        await state.storage.deleteAll();
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 6),
        );
        seedVersion6Rows(state.storage.sql);
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 9),
        );
        seedVersion9GoalRows(state.storage.sql);
        const rows = readAllRows(state.storage.sql);
        applyDurableObjectMigrations(state.storage, durableObjectMigrations);
        return rows;
      });
    });

    test("週の見直しと目標の経過の 7 つの表ができること", async () => {
      const tables = await runInAccount(account, (sql) =>
        sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name IN ('weekly_reviews', 'deferred_weekly_reviews', 'reviewed_expenditure_estimates', 'reviewed_daily_guides', 'goal_achievements', 'goal_deadline_confirmations', 'post_deadline_maintenance_goals') ORDER BY name",
          )
          .toArray()
          .map(({ name }) => name),
      );
      expect(tables).toEqual([
        "deferred_weekly_reviews",
        "goal_achievements",
        "goal_deadline_confirmations",
        "post_deadline_maintenance_goals",
        "reviewed_daily_guides",
        "reviewed_expenditure_estimates",
        "weekly_reviews",
      ]);
    });

    test("2 つの一意の索引が、それぞれの表にできること", async () => {
      const indexes = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT s.name AS name, s.tbl_name AS tbl_name, l.\"unique\" AS is_unique FROM sqlite_schema AS s JOIN pragma_index_list(s.tbl_name) AS l ON l.name = s.name WHERE s.type = 'index' AND s.name IN ('weekly_reviews_effective_on', 'reviewed_expenditure_estimates_weekly_review_id') ORDER BY s.name",
          )
          .toArray(),
      );
      expect(indexes).toEqual([
        {
          name: "reviewed_expenditure_estimates_weekly_review_id",
          tbl_name: "reviewed_expenditure_estimates",
          is_unique: 1,
        },
        { name: "weekly_reviews_effective_on", tbl_name: "weekly_reviews", is_unique: 1 },
      ]);
    });

    test("既存の表の行が変わらないこと", async () => {
      const rowsAfter = await runInAccount(account, readAllRows);
      expect(
        Object.fromEntries(Object.keys(rowsBefore).map((name) => [name, rowsAfter[name]])),
      ).toEqual(rowsBefore);
    });

    test("外部キーの違反が無いこと", async () => {
      const violations = await runInAccount(account, (sql) =>
        sql.exec("PRAGMA foreign_key_check").toArray(),
      );
      expect(violations).toEqual([]);
    });
  });
});

// 版 10 までの形の最初のサインインと週の見直し。版 11 の表のうち、無料体験なしが指す親の行
const seedVersion10Rows = (sql: Sql) => {
  sql.exec(
    "INSERT INTO first_sign_ins (id, started_on, signed_in_at, time_zone) VALUES ('first-sign-in-1', '2026-09-01', 0, 'Asia/Tokyo')",
  );
  sql.exec(
    "INSERT INTO weekly_reviews (id, effective_on, reviewed_at, time_zone) VALUES ('review-1', '2026-09-08', 0, 'Asia/Tokyo')",
  );
  sql.exec(
    "INSERT INTO deferred_weekly_reviews (weekly_review_id, goal_id, reason) VALUES ('review-1', 'goal-1', 'within_first_week')",
  );
};

describe("Durable Object の移行の版 11（課金の表）", () => {
  describe("版 10 までの形の食事・料理・材料・控え・目標・週の見直し・最初のサインインがあるとき", () => {
    let account: DurableObjectStub;
    let rowsBefore: Record<string, unknown[]>;
    beforeEach(async () => {
      account = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      rowsBefore = await runInDurableObject(account, async (_, state) => {
        await state.storage.deleteAll();
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 6),
        );
        seedVersion6Rows(state.storage.sql);
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 9),
        );
        seedVersion9GoalRows(state.storage.sql);
        applyDurableObjectMigrations(
          state.storage,
          durableObjectMigrations.filter(({ version }) => version <= 10),
        );
        seedVersion10Rows(state.storage.sql);
        const rows = readAllRows(state.storage.sql);
        applyDurableObjectMigrations(state.storage, durableObjectMigrations);
        return rows;
      });
    });

    test("課金の 15 の表ができること", async () => {
      const tables = await runInAccount(account, (sql) =>
        sql
          .exec<{ name: string }>(
            "SELECT name FROM sqlite_schema WHERE type = 'table' AND name IN ('subscriptions', 'app_store_subscriptions', 'subscription_transactions', 'app_store_subscription_transactions', 'subscription_transaction_revocations', 'subscription_transaction_revocation_reversals', 'subscription_billing_failures', 'subscription_grace_periods', 'subscription_receipts', 'app_store_notification_receipts', 'subscription_transaction_report_receipts', 'free_trial_exclusions', 'estimation_holds', 'reply_request_subscription_halts', 'terms_agreements') ORDER BY name",
          )
          .toArray()
          .map(({ name }) => name),
      );
      expect(tables).toEqual([
        "app_store_notification_receipts",
        "app_store_subscription_transactions",
        "app_store_subscriptions",
        "estimation_holds",
        "free_trial_exclusions",
        "reply_request_subscription_halts",
        "subscription_billing_failures",
        "subscription_grace_periods",
        "subscription_receipts",
        "subscription_transaction_report_receipts",
        "subscription_transaction_revocation_reversals",
        "subscription_transaction_revocations",
        "subscription_transactions",
        "subscriptions",
        "terms_agreements",
      ]);
    });

    test("3 つの一意の索引が、それぞれの表にできること", async () => {
      const indexes = await runInAccount(account, (sql) =>
        sql
          .exec(
            "SELECT s.name AS name, s.tbl_name AS tbl_name, l.\"unique\" AS is_unique FROM sqlite_schema AS s JOIN pragma_index_list(s.tbl_name) AS l ON l.name = s.name WHERE s.type = 'index' AND s.name IN ('app_store_subscriptions_environment', 'app_store_subscription_transactions_app_store_transaction_id', 'app_store_notification_receipts_notification_uuid') ORDER BY s.name",
          )
          .toArray(),
      );
      expect(indexes).toEqual([
        {
          name: "app_store_notification_receipts_notification_uuid",
          tbl_name: "app_store_notification_receipts",
          is_unique: 1,
        },
        {
          name: "app_store_subscription_transactions_app_store_transaction_id",
          tbl_name: "app_store_subscription_transactions",
          is_unique: 1,
        },
        {
          name: "app_store_subscriptions_environment",
          tbl_name: "app_store_subscriptions",
          is_unique: 1,
        },
      ]);
    });

    test("既存の表の行が変わらないこと", async () => {
      const rowsAfter = await runInAccount(account, readAllRows);
      expect(
        Object.fromEntries(Object.keys(rowsBefore).map((name) => [name, rowsAfter[name]])),
      ).toEqual(rowsBefore);
    });

    test("外部キーの違反が無いこと", async () => {
      const violations = await runInAccount(account, (sql) =>
        sql.exec("PRAGMA foreign_key_check").toArray(),
      );
      expect(violations).toEqual([]);
    });
  });
});

// 移行の版の表と Cloudflare・SQLite の表を除く、すべての表の行を、表の名前ごとに読む
const readAllRows = (sql: Sql): Record<string, unknown[]> =>
  Object.fromEntries(
    sql
      .exec<{ name: string }>(
        "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE '\\_cf\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite\\_%' ESCAPE '\\' AND name <> 'durable_object_migrations' ORDER BY name",
      )
      .toArray()
      .map(({ name }) => [name, sql.exec(`SELECT * FROM "${name}" ORDER BY rowid`).toArray()]),
  );
