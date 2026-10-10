-- 文章と会話の仕様（#419）の 20 の表と 6 つの索引を足す。CREATE だけで、既存の表は変えない。
-- 既存の列に足す区分の値（meals.entry_method の written、帳簿の record_type と kind、受け付けなかった理由）は、
-- 列に CHECK が無いので SQL の移行は要らない（#419 の Schema changes）。
-- 食事の子（sent_text_meals と、それを指す2つ）は ON DELETE CASCADE にする。1つ前の版のコードは、この表を知らずに食事を消すため

-- 送った文章と読み分け

CREATE TABLE sent_texts (
  id TEXT PRIMARY KEY,
  body TEXT NOT NULL,
  sent_at INTEGER NOT NULL,
  sent_time_zone TEXT NOT NULL
);

CREATE INDEX sent_texts_sent_at ON sent_texts (sent_at);

CREATE TABLE sent_text_classifications (
  sent_text_id TEXT PRIMARY KEY REFERENCES sent_texts (id),
  classified_at INTEGER NOT NULL,
  result TEXT NOT NULL
);

CREATE TABLE sent_text_conversation_resends (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id)
);

CREATE TABLE sent_text_resends (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id)
);

CREATE TABLE conversation_resend_meal_deletions (
  meal_id TEXT PRIMARY KEY,
  sync_write_receipt_id TEXT NOT NULL
    REFERENCES sent_text_conversation_resends (sync_write_receipt_id)
);

-- 文章の食事

CREATE TABLE sent_text_meals (
  meal_id TEXT PRIMARY KEY REFERENCES meals (id) ON DELETE CASCADE,
  sent_text_id TEXT NOT NULL REFERENCES sent_texts (id)
);

CREATE INDEX sent_text_meals_sent_text_id ON sent_text_meals (sent_text_id);

CREATE TABLE estimation_created_meals (
  meal_id TEXT PRIMARY KEY REFERENCES sent_text_meals (meal_id) ON DELETE CASCADE,
  estimation_id TEXT NOT NULL REFERENCES estimations (id)
);

CREATE TABLE meal_eaten_at_estimations (
  meal_id TEXT PRIMARY KEY REFERENCES sent_text_meals (meal_id) ON DELETE CASCADE,
  estimation_id TEXT NOT NULL REFERENCES estimations (id),
  eaten_at INTEGER NOT NULL
);

CREATE INDEX meal_eaten_at_estimations_eaten_at ON meal_eaten_at_estimations (eaten_at);

-- 返事

CREATE TABLE reply_requests (
  id TEXT PRIMARY KEY,
  sent_text_id TEXT NOT NULL REFERENCES sent_texts (id),
  counted_on TEXT NOT NULL
);

CREATE INDEX reply_requests_sent_text_id ON reply_requests (sent_text_id);
CREATE INDEX reply_requests_counted_on ON reply_requests (counted_on);

CREATE TABLE classification_reply_requests (
  reply_request_id TEXT PRIMARY KEY REFERENCES reply_requests (id)
);

CREATE TABLE resend_reply_requests (
  reply_request_id TEXT PRIMARY KEY REFERENCES reply_requests (id),
  sync_write_receipt_id TEXT NOT NULL UNIQUE REFERENCES sent_text_resends (sync_write_receipt_id)
);

CREATE TABLE conversation_resend_reply_requests (
  reply_request_id TEXT PRIMARY KEY REFERENCES reply_requests (id),
  sync_write_receipt_id TEXT NOT NULL UNIQUE
    REFERENCES sent_text_conversation_resends (sync_write_receipt_id)
);

CREATE TABLE reply_request_halts (
  reply_request_id TEXT PRIMARY KEY REFERENCES reply_requests (id),
  halted_at INTEGER NOT NULL
);

CREATE TABLE reply_generations (
  id TEXT PRIMARY KEY,
  reply_request_id TEXT NOT NULL UNIQUE REFERENCES reply_requests (id),
  started_at INTEGER NOT NULL
);

CREATE TABLE reply_generation_attempts (
  id TEXT PRIMARY KEY,
  reply_generation_id TEXT NOT NULL REFERENCES reply_generations (id),
  attempted_at INTEGER NOT NULL
);

CREATE INDEX reply_generation_attempts_reply_generation_id
ON reply_generation_attempts (reply_generation_id, attempted_at);

CREATE TABLE reply_generation_attempt_results (
  reply_generation_attempt_id TEXT PRIMARY KEY REFERENCES reply_generation_attempts (id),
  ended_at INTEGER NOT NULL,
  result TEXT NOT NULL
);

CREATE TABLE reply_generation_attempt_errors (
  reply_generation_attempt_id TEXT PRIMARY KEY
    REFERENCES reply_generation_attempt_results (reply_generation_attempt_id),
  error_type TEXT NOT NULL
);

CREATE TABLE reply_generation_abandonments (
  reply_generation_id TEXT PRIMARY KEY REFERENCES reply_generations (id),
  abandoned_at INTEGER NOT NULL
);

CREATE TABLE ai_utterances (
  reply_generation_id TEXT PRIMARY KEY REFERENCES reply_generations (id),
  body TEXT NOT NULL
);

CREATE TABLE ai_utterance_meals (
  ai_utterance_id TEXT NOT NULL REFERENCES ai_utterances (reply_generation_id),
  meal_id TEXT NOT NULL,
  position_in_utterance INTEGER NOT NULL,
  PRIMARY KEY (ai_utterance_id, meal_id)
);
