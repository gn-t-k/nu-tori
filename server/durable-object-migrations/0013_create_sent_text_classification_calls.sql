-- 読み分けで提供元を呼んだことと、その時刻。CREATE だけで、既存の表は変えない。
-- 書き足すだけで、UPDATE も DELETE も無い。提供元を呼ぶ前に書くので、結果を書けずに読み直した文章には呼んだ数だけ行がある。
-- 提供元を呼ばずに会話にした文章には行が無い。読み分けの回数を、直近 24 時間の呼んだ時刻で数える

CREATE TABLE sent_text_classification_calls (
  id TEXT PRIMARY KEY,
  sent_text_id TEXT NOT NULL REFERENCES sent_texts (id),
  called_at INTEGER NOT NULL
);

CREATE INDEX sent_text_classification_calls_called_at
ON sent_text_classification_calls (called_at);
