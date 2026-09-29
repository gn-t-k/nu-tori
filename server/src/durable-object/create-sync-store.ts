import { z } from "zod";
import type { SyncStore } from "../domain/sync-store";
import type { SyncWriteOutcome } from "../domain/sync-write-outcome";
import type { WeightRecord } from "../domain/weight-record";

export const createSyncStore = (storage: DurableObjectStorage): SyncStore => {
  const sql = storage.sql;
  return {
    transaction: (run) => storage.transactionSync(run),
    findStartedOn: () => {
      const [row] = sql
        .exec<{ started_on: string }>("SELECT started_on FROM first_sign_ins")
        .toArray();
      return row?.started_on;
    },
    insertPushRequestLog: ({ id, receivedAt, clientState, isFinalBatch }) => {
      insertRequestLog(sql, { id, receivedAt, clientState });
      sql.exec(
        "INSERT INTO sync_push_logs (sync_request_log_id, is_final_batch) VALUES (?, ?)",
        id,
        isFinalBatch ? 1 : 0,
      );
    },
    insertPullRequestLog: ({ id, receivedAt, clientState, afterSequence }) => {
      insertRequestLog(sql, { id, receivedAt, clientState });
      sql.exec(
        "INSERT INTO sync_pull_logs (sync_request_log_id, after_change_sequence) VALUES (?, ?)",
        id,
        afterSequence,
      );
    },
    findWriteOutcome: (writeId) => {
      const [row] = sql
        .exec<{ result: string; reason: string | null }>(
          `SELECT receipt.result, rejection.reason
           FROM sync_write_receipts AS receipt
           LEFT JOIN sync_write_rejections AS rejection ON rejection.sync_write_receipt_id = receipt.id
           WHERE receipt.id = ?`,
          writeId,
        )
        .toArray();
      return row === undefined ? undefined : parseOutcome(row);
    },
    insertWriteReceipt: ({
      writeId,
      requestLogId,
      positionInRequest,
      kind,
      recordType,
      recordId,
      outcome,
    }) => {
      sql.exec(
        `INSERT INTO sync_write_receipts
           (id, sync_request_log_id, position_in_request, kind, record_type, record_id, result)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        writeId,
        requestLogId,
        positionInRequest,
        kind,
        recordType,
        recordId,
        outcome.result,
      );
      if (outcome.result === "rejected") {
        sql.exec(
          "INSERT INTO sync_write_rejections (sync_write_receipt_id, reason) VALUES (?, ?)",
          writeId,
          outcome.reason,
        );
      }
    },
    findWeightRecord: (id) => {
      const [row] = sql
        .exec<WeightRecordRow>(
          `SELECT
             record.id, record.weight_kg, record.measured_at, record.time_zone, record.version,
             imported.source_app_name, imported.source_bundle_id,
             imported.healthkit_sample_uuid AS weight_sample_uuid,
             body_fat.body_fat_percentage,
             body_fat.healthkit_sample_uuid AS body_fat_sample_uuid
           FROM weight_records AS record
           LEFT JOIN imported_weight_records AS imported ON imported.weight_record_id = record.id
           LEFT JOIN imported_body_fat_percentages AS body_fat ON body_fat.weight_record_id = record.id
           WHERE record.id = ?`,
          id,
        )
        .toArray();
      return row === undefined ? undefined : toWeightRecord(row);
    },
    existsImportedSample: (healthkitSampleUuid) =>
      sql
        .exec(
          "SELECT 1 FROM imported_weight_records WHERE healthkit_sample_uuid = ?",
          healthkitSampleUuid,
        )
        .toArray().length > 0,
    insertWeightRecord: ({ id, weightKg, measuredAt, timeZone, version, imported }) => {
      sql.exec(
        `INSERT INTO weight_records (id, weight_kg, measured_at, time_zone, version)
         VALUES (?, ?, ?, ?, ?)`,
        id,
        weightKg,
        measuredAt.getTime(),
        timeZone,
        version,
      );
      if (imported === undefined) {
        return;
      }
      sql.exec(
        `INSERT INTO imported_weight_records
           (weight_record_id, source_app_name, source_bundle_id, healthkit_sample_uuid)
         VALUES (?, ?, ?, ?)`,
        id,
        imported.sourceAppName,
        imported.sourceBundleId,
        imported.healthkitSampleUuid,
      );
      if (imported.bodyFat === undefined) {
        return;
      }
      sql.exec(
        `INSERT INTO imported_body_fat_percentages
           (weight_record_id, body_fat_percentage, healthkit_sample_uuid)
         VALUES (?, ?, ?)`,
        id,
        imported.bodyFat.percentage,
        imported.bodyFat.healthkitSampleUuid,
      );
    },
    updateWeightRecord: (id, { weightKg, measuredAt, timeZone, version }) => {
      sql.exec(
        `UPDATE weight_records
         SET weight_kg = ?, measured_at = ?, time_zone = ?, version = ?
         WHERE id = ?`,
        weightKg,
        measuredAt.getTime(),
        timeZone,
        version,
        id,
      );
    },
    insertRecordChange: ({ recordType, recordId, writeId }) => {
      const { sequence } = sql
        .exec<{ sequence: number }>(
          "INSERT INTO record_changes (record_type, record_id) VALUES (?, ?) RETURNING sequence",
          recordType,
          recordId,
        )
        .one();
      sql.exec(
        "INSERT INTO sync_write_record_changes (record_change_sequence, sync_write_receipt_id) VALUES (?, ?)",
        sequence,
        writeId,
      );
    },
    findLatestChangePerRecord: (afterSequence, limit) =>
      sql
        .exec<{ sequence: number; record_type: string; record_id: string }>(
          `SELECT MAX(sequence) AS sequence, record_type, record_id
           FROM record_changes
           WHERE sequence > ?
           GROUP BY record_type, record_id
           ORDER BY MAX(sequence)
           LIMIT ?`,
          afterSequence,
          limit,
        )
        .toArray()
        .map((row) => ({
          sequence: row.sequence,
          recordType: parseRecordType(row.record_type),
          recordId: row.record_id,
        })),
  };
};

const insertRequestLog = (
  sql: SqlStorage,
  {
    id,
    receivedAt,
    clientState,
  }: {
    id: string;
    receivedAt: Date;
    clientState: Parameters<SyncStore["insertPushRequestLog"]>[0]["clientState"];
  },
): void => {
  sql.exec(
    `INSERT INTO sync_request_logs
       (id, device_id, received_at, time_zone, app_version, os_version,
        pending_write_count, oldest_pending_write_age_seconds, pending_photo_count)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    clientState.deviceId,
    receivedAt.getTime(),
    clientState.timeZone,
    clientState.appVersion,
    clientState.osVersion,
    clientState.pendingWriteCount,
    clientState.oldestPendingWriteAgeSeconds ?? null,
    clientState.pendingPhotoCount,
  );
};

const parseOutcome = (row: { result: string; reason: string | null }): SyncWriteOutcome => {
  const outcomeSchema = z.discriminatedUnion("result", [
    z.object({ result: z.enum(["applied", "ignored_duplicate"]) }),
    z.object({
      result: z.literal("rejected"),
      reason: z.enum([
        "out_of_range",
        "invalid_time_zone",
        "version_too_low",
        "record_not_found",
        "record_before_started_on",
      ]),
    }),
  ]);
  return outcomeSchema.parse({ result: row.result, reason: row.reason ?? undefined });
};

const parseRecordType = (recordType: string): "weight_record" => {
  if (recordType !== "weight_record") {
    throw new Error(`知らない記録の種類: ${recordType}`);
  }
  return recordType;
};

type WeightRecordRow = {
  id: string;
  weight_kg: number;
  measured_at: number;
  time_zone: string;
  version: number;
  source_app_name: string | null;
  source_bundle_id: string | null;
  weight_sample_uuid: string | null;
  body_fat_percentage: number | null;
  body_fat_sample_uuid: string | null;
};

const toWeightRecord = (row: WeightRecordRow): WeightRecord => ({
  id: row.id,
  weightKg: row.weight_kg,
  measuredAt: new Date(row.measured_at),
  timeZone: row.time_zone,
  version: row.version,
  imported:
    row.source_app_name === null || row.source_bundle_id === null || row.weight_sample_uuid === null
      ? undefined
      : {
          sourceAppName: row.source_app_name,
          sourceBundleId: row.source_bundle_id,
          healthkitSampleUuid: row.weight_sample_uuid,
          bodyFat:
            row.body_fat_percentage === null || row.body_fat_sample_uuid === null
              ? undefined
              : {
                  percentage: row.body_fat_percentage,
                  healthkitSampleUuid: row.body_fat_sample_uuid,
                },
        },
});
