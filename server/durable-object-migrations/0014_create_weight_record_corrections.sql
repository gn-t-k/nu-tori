-- 体重記録の直しを、記録の行を上書きせず、体重の修正と時刻の修正として書き足す形にする（#977）。
-- この移行だけ「足すだけ」の決まりから外れ、weight_records の version 列を落とす（#977 の Schema changes の「移行の決まりの例外」）。
-- 修正の表を作り、この移行より前に直した記録の今の値を、いちばんあとに当てた直す控えに埋め戻してから、列を落とす。
-- version は索引・UNIQUE・外部キー・CHECK・トリガー・ビューのどれにも使われていないので、表を作り直さずに DROP COLUMN で落とせる

CREATE TABLE weight_record_weight_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  weight_kg REAL NOT NULL
);

CREATE TABLE weight_record_measured_at_corrections (
  sync_write_receipt_id TEXT PRIMARY KEY REFERENCES sync_write_receipts (id),
  measured_at INTEGER NOT NULL,
  time_zone TEXT NOT NULL
);

CREATE INDEX weight_record_measured_at_corrections_measured_at
  ON weight_record_measured_at_corrections (measured_at);

-- 体重の修正は、直したすべての記録に置く。値は、上書きしてきた weight_records の今の値。
-- 置く控えは、当てた直す控えのうち、結ばれた変更の通し番号がいちばん大きいもの
INSERT INTO weight_record_weight_corrections (sync_write_receipt_id, weight_kg)
SELECT latest.sync_write_receipt_id, records.weight_kg
FROM (
  SELECT receipts.record_id AS weight_record_id, changes.sync_write_receipt_id,
    ROW_NUMBER() OVER (
      PARTITION BY receipts.record_id ORDER BY changes.record_change_sequence DESC
    ) AS position_from_latest
  FROM sync_write_receipts AS receipts
  INNER JOIN sync_write_record_changes AS changes ON changes.sync_write_receipt_id = receipts.id
  WHERE receipts.record_type = 'weight_record'
    AND receipts.kind = 'update'
    AND receipts.result = 'applied'
) AS latest
INNER JOIN weight_records AS records ON records.id = latest.weight_record_id
WHERE latest.position_from_latest = 1;

-- 時刻の修正は、手で記録した記録にだけ、体重の修正と同じ控えに置く。取り込んだ記録を直す場面は値だけを変えるので、時刻は直していない
INSERT INTO weight_record_measured_at_corrections (sync_write_receipt_id, measured_at, time_zone)
SELECT corrections.sync_write_receipt_id, records.measured_at, records.time_zone
FROM weight_record_weight_corrections AS corrections
INNER JOIN sync_write_receipts AS receipts ON receipts.id = corrections.sync_write_receipt_id
INNER JOIN weight_records AS records ON records.id = receipts.record_id
WHERE NOT EXISTS (
  SELECT 1 FROM imported_weight_records AS imported WHERE imported.weight_record_id = records.id
);

ALTER TABLE weight_records DROP COLUMN version;
