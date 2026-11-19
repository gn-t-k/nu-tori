import { env, runInDurableObject } from "cloudflare:test";
import { describe, expect, test } from "vitest";

// Durable Object の SQLite の外部キーと索引は、黙って効かなくなっても気づけるよう、知らせと体重記録の表で確かめる
type Sql = DurableObjectStorage["sql"];

describe("知らせの表の制約", () => {
  describe("答えのある記録忘れの知らせがあるとき", () => {
    test("知らせを消すと、記録忘れの知らせの子と答えも消えること", async () => {
      const counts = await runInAccount((sql) => {
        insertMissedRecordNotice(sql, "notice-1");
        insertReceipt(sql, "receipt-1");
        insertResponse(sql, "receipt-1", "notice-1");
        sql.exec("DELETE FROM notices WHERE id = 'notice-1'");
        return {
          notices: countRows(sql, "notices"),
          missedRecordNotices: countRows(sql, "missed_record_notices"),
          responses: countRows(sql, "notice_responses"),
        };
      });
      expect(counts).toEqual({ notices: 0, missedRecordNotices: 0, responses: 0 });
    });
  });

  describe("知らせが無いとき", () => {
    test("知らせの無い答えは INSERT できないこと", async () => {
      await expect(
        runInAccount((sql) => {
          insertReceipt(sql, "receipt-1");
          insertResponse(sql, "receipt-1", "notice-missing");
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });

  describe("書き込みの控えが無いとき", () => {
    test("控えの無いいつもの時刻の変更は INSERT できないこと", async () => {
      await expect(
        runInAccount((sql) => {
          sql.exec(
            "INSERT INTO usual_weighing_time_changes (sync_write_receipt_id, minute_of_day) VALUES ('receipt-missing', 435)",
          );
        }),
      ).rejects.toThrow(/FOREIGN KEY/);
    });
  });
});

describe("体重記録の表の索引", () => {
  test("時刻の範囲で体重記録の候補を引くとき、作ったときの時刻の索引を使うこと", async () => {
    const plan = await runInAccount((sql) =>
      sql
        .exec<{ detail: string }>(
          "EXPLAIN QUERY PLAN SELECT id FROM weight_records WHERE measured_at >= 0 AND measured_at < 1",
        )
        .toArray()
        .map((row) => row.detail),
    );
    expect(plan).toEqual([
      "SEARCH weight_records USING INDEX weight_records_measured_at (measured_at>? AND measured_at<?)",
    ]);
  });

  test("時刻の範囲で体重記録の候補を引くとき、直した時刻の索引を使うこと", async () => {
    const plan = await runInAccount((sql) =>
      sql
        .exec<{ detail: string }>(
          "EXPLAIN QUERY PLAN SELECT receipts.record_id FROM weight_record_measured_at_corrections AS corrections INNER JOIN sync_write_receipts AS receipts ON receipts.id = corrections.sync_write_receipt_id WHERE corrections.measured_at >= 0 AND corrections.measured_at < 1",
        )
        .toArray()
        .map((row) => row.detail),
    );
    expect(plan).toEqual([
      "SEARCH corrections USING INDEX weight_record_measured_at_corrections_measured_at (measured_at>? AND measured_at<?)",
      "SEARCH receipts USING INDEX sqlite_autoindex_sync_write_receipts_1 (id=?)",
    ]);
  });
  test("時刻の範囲の候補の、直した時刻を引くとき、体重記録の控えと変更の並びを全部なめないこと", async () => {
    const plan = await runInAccount((sql) =>
      sql
        .exec<{ detail: string }>(
          "EXPLAIN QUERY PLAN SELECT receipts.record_id, corrections.measured_at, changes.record_change_sequence FROM weight_record_measured_at_corrections AS corrections INNER JOIN sync_write_receipts AS receipts ON receipts.id = corrections.sync_write_receipt_id INNER JOIN sync_write_record_changes AS changes ON changes.sync_write_receipt_id = corrections.sync_write_receipt_id WHERE receipts.record_id IN (SELECT id FROM weight_records WHERE measured_at >= 0 AND measured_at < 1) OR receipts.record_id IN (SELECT receipts2.record_id FROM weight_record_measured_at_corrections AS corrections2 INNER JOIN sync_write_receipts AS receipts2 ON receipts2.id = corrections2.sync_write_receipt_id WHERE corrections2.measured_at >= 0 AND corrections2.measured_at < 1)",
        )
        .toArray()
        .map((row) => row.detail),
    );
    // 修正の表から引き、控えと変更の並びは主キーと一意の索引で1行ずつ引く。修正の数だけ読み、記録や変更の数によらない
    expect(plan).toEqual([
      "SCAN corrections",
      "SEARCH receipts USING INDEX sqlite_autoindex_sync_write_receipts_1 (id=?)",
      "LIST SUBQUERY 1",
      "SEARCH weight_records USING INDEX weight_records_measured_at (measured_at>? AND measured_at<?)",
      "CREATE BLOOM FILTER",
      "LIST SUBQUERY 2",
      "SEARCH corrections2 USING INDEX weight_record_measured_at_corrections_measured_at (measured_at>? AND measured_at<?)",
      "SEARCH receipts2 USING INDEX sqlite_autoindex_sync_write_receipts_1 (id=?)",
      "CREATE BLOOM FILTER",
      "SEARCH changes USING COVERING INDEX sync_write_record_changes_receipt (sync_write_receipt_id=?)",
    ]);
  });
});

const runInAccount = <T>(run: (sql: Sql) => T): Promise<T> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), (_, state) =>
    run(state.storage.sql),
  );

const countRows = (sql: Sql, table: string): number =>
  sql.exec<{ count: number }>(`SELECT count(*) AS count FROM ${table}`).one().count;

const insertMissedRecordNotice = (sql: Sql, id: string) => {
  sql.exec(
    "INSERT INTO notices (id, notice_type, issued_at, time_zone) VALUES (?, 'missed_weight_record', 0, 'Asia/Tokyo')",
    id,
  );
  sql.exec("INSERT INTO missed_record_notices (notice_id, target_on) VALUES (?, '2026-01-01')", id);
};

// 答える書き込みの控え。控えの要求の行も、初めのときだけ足す
const insertReceipt = (sql: Sql, id: string) => {
  sql.exec(
    "INSERT OR IGNORE INTO sync_request_logs (id, device_id, received_at, time_zone, app_version, os_version, pending_write_count, pending_photo_count) VALUES ('request-1', 'device-1', 0, 'Asia/Tokyo', '1.0.0', '26.0', 1, 0)",
  );
  sql.exec(
    "INSERT OR IGNORE INTO sync_push_logs (sync_request_log_id, is_final_batch) VALUES ('request-1', 1)",
  );
  sql.exec(
    "INSERT INTO sync_write_receipts (id, sync_request_log_id, position_in_request, kind, record_type, record_id, result) VALUES (?, 'request-1', 0, 'respond', 'notice', 'notice-1', 'applied')",
    id,
  );
};

const insertResponse = (sql: Sql, receiptId: string, noticeId: string) => {
  sql.exec(
    "INSERT INTO notice_responses (sync_write_receipt_id, notice_id, responded_at, time_zone) VALUES (?, ?, 0, 'Asia/Tokyo')",
    receiptId,
    noticeId,
  );
};
