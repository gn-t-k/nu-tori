-- 目標を立てる仕様（#523）の 8 つの表と 3 つの一意の索引を足す。CREATE だけで、既存の表は変えない。
-- 既存の列に足す区分の値（notices.notice_type の goal_setup、帳簿の record_type の goal・daily_guide・expenditure_estimate）は、
-- 列に CHECK が無いので SQL の移行は要らない（#523 の Schema changes）。
-- どの表も書き足すだけで、UPDATE も DELETE も無い。外部キーはこの移行の表どうしに閉じ、既存の表を指さない。
-- 索引の名前は先頭の列で名付ける

-- 目標

CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  started_on TEXT NOT NULL,
  starting_weight_trend_kg REAL NOT NULL,
  target_weight_kg REAL NOT NULL,
  decided_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE TABLE weight_change_goals (
  goal_id TEXT PRIMARY KEY REFERENCES goals (id),
  deadline_on TEXT NOT NULL,
  pace_plan TEXT NOT NULL
);

CREATE TABLE goal_closures (
  goal_id TEXT PRIMARY KEY REFERENCES goals (id),
  next_goal_id TEXT NOT NULL REFERENCES goals (id)
);

CREATE UNIQUE INDEX goal_closures_next_goal_id ON goal_closures (next_goal_id);

CREATE TABLE goal_decision_receipts (
  id TEXT PRIMARY KEY,
  goal_id TEXT NOT NULL REFERENCES goals (id)
);

CREATE UNIQUE INDEX goal_decision_receipts_goal_id ON goal_decision_receipts (goal_id);

-- 推定消費カロリーと1日の目安

CREATE TABLE expenditure_estimates (
  id TEXT PRIMARY KEY,
  effective_on TEXT NOT NULL,
  expenditure_kcal INTEGER NOT NULL,
  estimated_at INTEGER NOT NULL
);

CREATE TABLE initial_expenditure_estimates (
  expenditure_estimate_id TEXT PRIMARY KEY REFERENCES expenditure_estimates (id),
  source TEXT NOT NULL
);

CREATE TABLE daily_guides (
  id TEXT PRIMARY KEY,
  goal_id TEXT NOT NULL REFERENCES goals (id),
  expenditure_estimate_id TEXT NOT NULL REFERENCES expenditure_estimates (id),
  effective_on TEXT NOT NULL,
  energy_kcal INTEGER NOT NULL,
  protein_g INTEGER NOT NULL,
  fat_g INTEGER NOT NULL,
  carbohydrate_g INTEGER NOT NULL
);

CREATE UNIQUE INDEX daily_guides_goal_id ON daily_guides (goal_id, effective_on);

CREATE TABLE daily_guide_limit_hits (
  daily_guide_id TEXT NOT NULL REFERENCES daily_guides (id),
  limit_type TEXT NOT NULL,
  PRIMARY KEY (daily_guide_id, limit_type)
);
