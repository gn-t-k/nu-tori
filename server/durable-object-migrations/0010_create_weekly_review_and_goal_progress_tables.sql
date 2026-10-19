-- 週の見直しと目標の経過の仕様（#613）の 7 つの表と 2 つの一意の索引を足す。CREATE だけで、既存の表は変えない。
-- 既存の列に足す区分の値（帳簿の record_type の weekly_review）は、列に CHECK が無いので SQL の移行は要らない（#613 の Schema changes）。
-- どの表も書き足すだけで、UPDATE も DELETE も無い。外部キーは 0009 の表（goals・weight_change_goals・expenditure_estimates・daily_guides）と
-- この移行の weekly_reviews だけを指す。親の表は消さないので ON DELETE は付けない。
-- 索引の名前は先頭の列で名付ける

-- 週の見直し

CREATE TABLE weekly_reviews (
  id TEXT PRIMARY KEY,
  effective_on TEXT NOT NULL,
  reviewed_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE UNIQUE INDEX weekly_reviews_effective_on ON weekly_reviews (effective_on);

CREATE TABLE deferred_weekly_reviews (
  weekly_review_id TEXT PRIMARY KEY REFERENCES weekly_reviews (id),
  goal_id TEXT NOT NULL REFERENCES goals (id),
  reason TEXT NOT NULL
);

-- 推定消費カロリー

CREATE TABLE reviewed_expenditure_estimates (
  expenditure_estimate_id TEXT PRIMARY KEY REFERENCES expenditure_estimates (id),
  weekly_review_id TEXT NOT NULL REFERENCES weekly_reviews (id),
  deviation_direction TEXT NOT NULL
);

CREATE UNIQUE INDEX reviewed_expenditure_estimates_weekly_review_id
  ON reviewed_expenditure_estimates (weekly_review_id);

-- 1日の目安

CREATE TABLE reviewed_daily_guides (
  daily_guide_id TEXT PRIMARY KEY REFERENCES daily_guides (id),
  main_reason TEXT NOT NULL
);

-- 目標

CREATE TABLE goal_achievements (
  goal_id TEXT PRIMARY KEY REFERENCES weight_change_goals (goal_id),
  achieved_on TEXT NOT NULL,
  judged_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE TABLE goal_deadline_confirmations (
  goal_id TEXT PRIMARY KEY REFERENCES weight_change_goals (goal_id),
  deadline_weight_trend_kg REAL NOT NULL,
  confirmed_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE TABLE post_deadline_maintenance_goals (
  goal_id TEXT PRIMARY KEY REFERENCES goals (id)
);
