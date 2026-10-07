-- 料理と材料の表を作り直し、食事を直す仕様（#332）の表を足す。
-- この移行だけ「足すだけ」の決まりから外れる（#332 の Schema changes の「移行の決まりの例外」）。
-- SQLite は列の制約を変えられず、移行のトランザクションの中では PRAGMA foreign_keys = OFF が効かないので、
-- 写しに移す → 子から DROP → 親から CREATE → 親から写し戻す → 写しを DROP の順にする。
-- 子から DROP し、親から写し戻すので、どの文もその場で外部キーを満たす（PRAGMA defer_foreign_keys は使わない）

-- 1. 写しに移す（外部キーの無い CREATE TABLE … AS SELECT）

-- 料理ごとに、食事のいちばん新しい「推定できた」の完了の推定を、当てた推定にする
CREATE TABLE migration_0007_dish_estimation_applications AS
SELECT dish_id, estimation_id
FROM (
  SELECT
    dishes.id AS dish_id,
    estimations.id AS estimation_id,
    row_number() OVER (
      PARTITION BY dishes.id
      ORDER BY estimation_completions.completed_at DESC, estimations.started_at DESC
    ) AS rank
  FROM dishes
  JOIN meal_estimation_schedules ON meal_estimation_schedules.meal_id = dishes.meal_id
  JOIN estimations ON estimations.estimation_schedule_id = meal_estimation_schedules.estimation_schedule_id
  JOIN estimation_completions ON estimation_completions.estimation_id = estimations.id
  WHERE estimation_completions.result = 'estimated'
)
WHERE rank = 1;

CREATE TABLE migration_0007_dishes AS
SELECT id, meal_id, name, quantity, unit, position_in_meal FROM dishes;

CREATE TABLE migration_0007_ingredients AS
SELECT id, dish_id, name, quantity, unit, edible_grams_per_unit, position_in_dish FROM ingredients;

CREATE TABLE migration_0007_food_composition_ingredients AS
SELECT ingredient_id, food_number FROM food_composition_ingredients;

CREATE TABLE migration_0007_nutrition_label_ingredients AS
SELECT ingredient_id, label_basis_grams FROM nutrition_label_ingredients;

CREATE TABLE migration_0007_ingredient_nutrients AS
SELECT id, ingredient_id, nutrient, amount_per_basis FROM ingredient_nutrients;

-- 控えの無い削除の印は #188 のコードが書かないので無い。あれば控えが NULL になり、写し戻す INSERT が NOT NULL で止まる
CREATE TABLE migration_0007_dish_deletions AS
SELECT dish_deletions.dish_id, sync_write_dish_deletions.sync_write_receipt_id
FROM dish_deletions
LEFT JOIN sync_write_dish_deletions ON sync_write_dish_deletions.dish_id = dish_deletions.dish_id;

CREATE TABLE migration_0007_ingredient_deletions AS
SELECT ingredient_deletions.ingredient_id, sync_write_ingredient_deletions.sync_write_receipt_id
FROM ingredient_deletions
LEFT JOIN sync_write_ingredient_deletions
  ON sync_write_ingredient_deletions.ingredient_id = ingredient_deletions.ingredient_id;

-- 2. 子から DROP

DROP TABLE ingredient_nutrients;
DROP TABLE nutrition_label_ingredients;
DROP TABLE food_composition_ingredients;
DROP TABLE ingredients;
DROP TABLE dishes;
DROP TABLE sync_write_ingredient_deletions;
DROP TABLE ingredient_deletions;
DROP TABLE sync_write_dish_deletions;
DROP TABLE dish_deletions;

-- 3. 親から CREATE と索引

CREATE TABLE dishes (
  id TEXT PRIMARY KEY,
  meal_id TEXT NOT NULL REFERENCES meals (id),
  name TEXT NOT NULL,
  position_in_meal INTEGER NOT NULL
);

CREATE INDEX dishes_meal_id ON dishes (meal_id, position_in_meal);

CREATE TABLE dish_estimation_applications (
  dish_id TEXT NOT NULL REFERENCES dishes (id) ON DELETE CASCADE,
  estimation_id TEXT NOT NULL REFERENCES estimations (id),
  PRIMARY KEY (dish_id, estimation_id)
);

CREATE TABLE dish_estimated_quantities (
  dish_id TEXT NOT NULL,
  estimation_id TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  PRIMARY KEY (dish_id, estimation_id),
  FOREIGN KEY (dish_id, estimation_id)
    REFERENCES dish_estimation_applications (dish_id, estimation_id) ON DELETE CASCADE
);

CREATE TABLE ingredients (
  id TEXT PRIMARY KEY,
  dish_id TEXT NOT NULL,
  estimation_id TEXT NOT NULL,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  edible_grams_per_unit REAL NOT NULL,
  position_in_dish INTEGER NOT NULL,
  FOREIGN KEY (dish_id, estimation_id)
    REFERENCES dish_estimation_applications (dish_id, estimation_id)
);

CREATE INDEX ingredients_application ON ingredients (dish_id, estimation_id, position_in_dish);

CREATE TABLE food_composition_ingredients (
  ingredient_id TEXT PRIMARY KEY REFERENCES ingredients (id) ON DELETE CASCADE,
  food_number TEXT NOT NULL
);

CREATE TABLE nutrition_label_ingredients (
  ingredient_id TEXT PRIMARY KEY REFERENCES ingredients (id) ON DELETE CASCADE,
  label_basis_grams REAL NOT NULL
);

CREATE TABLE ingredient_nutrients (
  id TEXT PRIMARY KEY,
  ingredient_id TEXT NOT NULL REFERENCES ingredients (id) ON DELETE CASCADE,
  nutrient TEXT NOT NULL,
  amount_per_basis REAL NOT NULL
);

CREATE UNIQUE INDEX ingredient_nutrients_nutrient ON ingredient_nutrients (ingredient_id, nutrient);

CREATE TABLE dish_deletions (
  dish_id TEXT PRIMARY KEY,
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

CREATE TABLE ingredient_deletions (
  ingredient_id TEXT PRIMARY KEY,
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

CREATE TABLE meal_eaten_at_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  eaten_at INTEGER NOT NULL
);

CREATE INDEX meal_eaten_at_corrections_eaten_at ON meal_eaten_at_corrections (eaten_at);

CREATE TABLE dish_name_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  name TEXT NOT NULL
);

CREATE TABLE dish_quantity_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  quantity REAL NOT NULL
);

CREATE TABLE dish_quantity_correction_ingredients (
  sync_write_receipt_id TEXT NOT NULL
    REFERENCES dish_quantity_corrections (sync_write_receipt_id) ON DELETE CASCADE,
  ingredient_id TEXT NOT NULL REFERENCES ingredients (id) ON DELETE CASCADE,
  quantity REAL NOT NULL,
  PRIMARY KEY (sync_write_receipt_id, ingredient_id)
);

CREATE INDEX dish_quantity_correction_ingredients_ingredient_id
  ON dish_quantity_correction_ingredients (ingredient_id);

CREATE TABLE ingredient_quantity_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  quantity REAL NOT NULL
);

CREATE TABLE dish_estimation_schedules (
  estimation_schedule_id TEXT PRIMARY KEY REFERENCES estimation_schedules (id),
  dish_id TEXT NOT NULL REFERENCES dishes (id) ON DELETE CASCADE
);

CREATE INDEX dish_estimation_schedules_dish_id ON dish_estimation_schedules (dish_id);

CREATE TABLE estimation_schedule_cancellations (
  estimation_schedule_id TEXT PRIMARY KEY
    REFERENCES dish_estimation_schedules (estimation_schedule_id) ON DELETE CASCADE,
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

-- 4. 親から写し戻す

INSERT INTO dishes (id, meal_id, name, position_in_meal)
SELECT id, meal_id, name, position_in_meal FROM migration_0007_dishes;

INSERT INTO dish_estimation_applications (dish_id, estimation_id)
SELECT dish_id, estimation_id FROM migration_0007_dish_estimation_applications;

-- 当てた推定の無い料理は estimation_id が NULL になり、NOT NULL で止まる（#188 のコードは料理を推定できたの完了と同じトランザクションでだけ作るので起きない）
INSERT INTO dish_estimated_quantities (dish_id, estimation_id, quantity, unit)
SELECT
  migration_0007_dishes.id,
  migration_0007_dish_estimation_applications.estimation_id,
  migration_0007_dishes.quantity,
  migration_0007_dishes.unit
FROM migration_0007_dishes
LEFT JOIN migration_0007_dish_estimation_applications
  ON migration_0007_dish_estimation_applications.dish_id = migration_0007_dishes.id;

INSERT INTO ingredients (
  id, dish_id, estimation_id, name, quantity, unit, edible_grams_per_unit, position_in_dish
)
SELECT
  migration_0007_ingredients.id,
  migration_0007_ingredients.dish_id,
  migration_0007_dish_estimation_applications.estimation_id,
  migration_0007_ingredients.name,
  migration_0007_ingredients.quantity,
  migration_0007_ingredients.unit,
  migration_0007_ingredients.edible_grams_per_unit,
  migration_0007_ingredients.position_in_dish
FROM migration_0007_ingredients
LEFT JOIN migration_0007_dish_estimation_applications
  ON migration_0007_dish_estimation_applications.dish_id = migration_0007_ingredients.dish_id;

INSERT INTO food_composition_ingredients (ingredient_id, food_number)
SELECT ingredient_id, food_number FROM migration_0007_food_composition_ingredients;

INSERT INTO nutrition_label_ingredients (ingredient_id, label_basis_grams)
SELECT ingredient_id, label_basis_grams FROM migration_0007_nutrition_label_ingredients;

INSERT INTO ingredient_nutrients (id, ingredient_id, nutrient, amount_per_basis)
SELECT id, ingredient_id, nutrient, amount_per_basis FROM migration_0007_ingredient_nutrients;

INSERT INTO dish_deletions (dish_id, sync_write_receipt_id)
SELECT dish_id, sync_write_receipt_id FROM migration_0007_dish_deletions;

INSERT INTO ingredient_deletions (ingredient_id, sync_write_receipt_id)
SELECT ingredient_id, sync_write_receipt_id FROM migration_0007_ingredient_deletions;

-- 5. 写しを DROP

DROP TABLE migration_0007_dish_estimation_applications;
DROP TABLE migration_0007_dishes;
DROP TABLE migration_0007_ingredients;
DROP TABLE migration_0007_food_composition_ingredients;
DROP TABLE migration_0007_nutrition_label_ingredients;
DROP TABLE migration_0007_ingredient_nutrients;
DROP TABLE migration_0007_dish_deletions;
DROP TABLE migration_0007_ingredient_deletions;
