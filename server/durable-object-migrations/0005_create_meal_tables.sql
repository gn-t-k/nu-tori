CREATE TABLE meals (
  id TEXT PRIMARY KEY,
  eaten_at INTEGER NOT NULL,
  eaten_at_utc_offset_seconds INTEGER NOT NULL,
  sent_at INTEGER NOT NULL,
  sent_time_zone TEXT NOT NULL,
  entry_method TEXT NOT NULL
);

CREATE INDEX meals_eaten_at ON meals (eaten_at);

CREATE TABLE meal_photos (
  id TEXT PRIMARY KEY,
  meal_id TEXT NOT NULL REFERENCES meals (id),
  position_in_meal INTEGER NOT NULL
);

CREATE UNIQUE INDEX meal_photos_position ON meal_photos (meal_id, position_in_meal);

CREATE TABLE meal_photo_file_receipts (
  meal_photo_id TEXT PRIMARY KEY,
  received_at INTEGER NOT NULL
);

CREATE TABLE meal_photo_file_deletions (
  meal_photo_id TEXT PRIMARY KEY REFERENCES meal_photo_file_receipts (meal_photo_id),
  deleted_at INTEGER NOT NULL
);

CREATE TABLE meal_photo_deletions (
  meal_photo_id TEXT PRIMARY KEY,
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

CREATE TABLE meal_deletions (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id)
);

CREATE TABLE estimation_schedules (
  id TEXT PRIMARY KEY,
  due_at INTEGER NOT NULL,
  counted_on TEXT NOT NULL
);

CREATE INDEX estimation_schedules_counted_on ON estimation_schedules (counted_on);

CREATE TABLE meal_estimation_schedules (
  estimation_schedule_id TEXT PRIMARY KEY REFERENCES estimation_schedules (id),
  meal_id TEXT NOT NULL REFERENCES meals (id) ON DELETE CASCADE
);

CREATE INDEX meal_estimation_schedules_meal_id ON meal_estimation_schedules (meal_id);

CREATE TABLE estimation_deferrals (
  estimation_schedule_id TEXT PRIMARY KEY REFERENCES estimation_schedules (id),
  deferred_at INTEGER NOT NULL
);

CREATE TABLE estimations (
  id TEXT PRIMARY KEY,
  estimation_schedule_id TEXT NOT NULL REFERENCES estimation_schedules (id),
  started_at INTEGER NOT NULL
);

CREATE UNIQUE INDEX estimations_estimation_schedule_id ON estimations (estimation_schedule_id);

CREATE TABLE estimation_attempts (
  id TEXT PRIMARY KEY,
  estimation_id TEXT NOT NULL REFERENCES estimations (id),
  attempted_at INTEGER NOT NULL
);

CREATE INDEX estimation_attempts_estimation_id ON estimation_attempts (estimation_id, attempted_at);

CREATE TABLE estimation_attempt_results (
  estimation_attempt_id TEXT PRIMARY KEY REFERENCES estimation_attempts (id),
  ended_at INTEGER NOT NULL,
  result TEXT NOT NULL
);

CREATE TABLE estimation_attempt_errors (
  estimation_attempt_id TEXT PRIMARY KEY REFERENCES estimation_attempt_results (estimation_attempt_id),
  error_type TEXT NOT NULL
);

CREATE TABLE estimation_completions (
  estimation_id TEXT PRIMARY KEY REFERENCES estimations (id),
  completed_at INTEGER NOT NULL,
  result TEXT NOT NULL
);

CREATE TABLE estimation_abandonments (
  estimation_id TEXT PRIMARY KEY REFERENCES estimations (id),
  abandoned_at INTEGER NOT NULL
);

CREATE TABLE dishes (
  id TEXT PRIMARY KEY,
  meal_id TEXT NOT NULL REFERENCES meals (id),
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  position_in_meal INTEGER NOT NULL,
  version INTEGER NOT NULL
);

CREATE INDEX dishes_meal_id ON dishes (meal_id, position_in_meal);

CREATE TABLE ingredients (
  id TEXT PRIMARY KEY,
  dish_id TEXT NOT NULL REFERENCES dishes (id),
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  edible_grams_per_unit REAL NOT NULL,
  position_in_dish INTEGER NOT NULL
);

CREATE INDEX ingredients_dish_id ON ingredients (dish_id, position_in_dish);

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
  dish_id TEXT PRIMARY KEY
);

CREATE TABLE sync_write_dish_deletions (
  dish_id TEXT PRIMARY KEY REFERENCES dish_deletions (dish_id),
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);

CREATE TABLE ingredient_deletions (
  ingredient_id TEXT PRIMARY KEY
);

CREATE TABLE sync_write_ingredient_deletions (
  ingredient_id TEXT PRIMARY KEY REFERENCES ingredient_deletions (ingredient_id),
  sync_write_receipt_id TEXT NOT NULL REFERENCES sync_write_receipts (id)
);
