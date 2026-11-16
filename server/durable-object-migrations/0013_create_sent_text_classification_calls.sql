-- 読み分けで提供元を呼んだ文章と、その数える日。CREATE だけで、既存の表は変えない。
-- 書き足すだけで、UPDATE も DELETE も無い。提供元を呼ばずに会話にした文章には行が無い。
-- 1日の読み分けの回数を、数える日で数える

CREATE TABLE sent_text_classification_calls (
  sent_text_id TEXT PRIMARY KEY REFERENCES sent_texts (id),
  counted_on TEXT NOT NULL
);

CREATE INDEX sent_text_classification_calls_counted_on
ON sent_text_classification_calls (counted_on);
