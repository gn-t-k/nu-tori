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
  test("体重記録を時刻の順に読むとき、時刻の索引を使うこと", async () => {
    const plan = await runInAccount((sql) =>
      sql
        .exec<{ detail: string }>(
          "EXPLAIN QUERY PLAN SELECT id FROM weight_records ORDER BY measured_at",
        )
        .toArray()
        .map((row) => row.detail),
    );
    expect(plan).toEqual(["SCAN weight_records USING INDEX weight_records_measured_at"]);
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
