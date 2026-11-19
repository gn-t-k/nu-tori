import { type SQL, and, count, eq, gte, inArray, lt, or } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import type { CorrectionTable } from "../../durable-object/correction-table";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { WeightRecord } from "../domain/weight-record";
import type { WeightRecordStore } from "../domain/weight-record-store";
import { weightRecordTables } from "./weight-record-tables";

const { syncWriteReceipts, syncWriteRecordChanges } = syncLedgerTables;
const {
  weightRecords,
  importedWeightRecords,
  importedBodyFatPercentages,
  weightRecordDeletions,
  weightRecordWeightCorrections,
  weightRecordMeasuredAtCorrections,
} = weightRecordTables;

export const createWeightRecordStore = (db: DrizzleSqliteDODatabase): WeightRecordStore => ({
  find: (id) => {
    const row = db
      .select({
        record: weightRecords,
        imported: importedWeightRecords,
        bodyFat: importedBodyFatPercentages,
      })
      .from(weightRecords)
      .leftJoin(importedWeightRecords, eq(importedWeightRecords.weightRecordId, weightRecords.id))
      .leftJoin(
        importedBodyFatPercentages,
        eq(importedBodyFatPercentages.weightRecordId, weightRecords.id),
      )
      .where(eq(weightRecords.id, id))
      .get();
    if (row === undefined) {
      return undefined;
    }
    // まとめて読む口と同じ関数で、この記録の分だけ読む。今の値の手順を1つにし、読む口ごとに食い違わないようにする
    const receiptFilter = isReceiptOfRecord(id);
    const weightKg = findLatestWeightCorrections(db, receiptFilter).get(id) ?? row.record.weightKg;
    const measured = findLatestMeasuredAtCorrections(db, receiptFilter).get(id) ?? row.record;
    return toWeightRecord({
      ...row,
      current: { weightKg, measuredAt: measured.measuredAt, timeZone: measured.timeZone },
      version: countVersion(db, id),
    });
  },
  // 記録ごとに今の値を引くと記録の数 × 2 のクエリになるので、3つのクエリでまとめて読み、アプリで今の値を当ててから並べる。
  // 並べる値は修正の表にもあるので、索引では並べられない
  findAllInMeasuredOrder: () => {
    const latestWeights = findLatestWeightCorrections(db);
    const latestMeasuredAts = findLatestMeasuredAtCorrections(db);
    return sortByMeasuredAt(
      db
        .select({
          id: weightRecords.id,
          weightKg: weightRecords.weightKg,
          measuredAt: weightRecords.measuredAt,
          timeZone: weightRecords.timeZone,
        })
        .from(weightRecords)
        .all()
        .map((record) => ({
          id: record.id,
          weightKg: latestWeights.get(record.id) ?? record.weightKg,
          ...(latestMeasuredAts.get(record.id) ?? {
            measuredAt: record.measuredAt,
            timeZone: record.timeZone,
          }),
        })),
    );
  },
  // 食事の時刻の範囲の読み方と同じく、作ったときの時刻と直した時刻の両方から候補を出し、候補ごとの今の時刻で絞る。
  // 今の時刻はそのどちらかなので抜けない。作ったときの時刻だけで引くと、直して範囲をまたいだ記録を数え誤る。
  // 体重の書き込みのたびに走るので、候補の数によらず2つのクエリで読む（候補はサブクエリで渡す）
  findMeasuredBetween: (from, to) => {
    const createdInRange = db
      .select({ id: weightRecords.id })
      .from(weightRecords)
      .where(and(gte(weightRecords.measuredAt, from), lt(weightRecords.measuredAt, to)));
    const correctedInRange = db
      .select({ id: syncWriteReceipts.recordId })
      .from(weightRecordMeasuredAtCorrections)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, weightRecordMeasuredAtCorrections.syncWriteReceiptId),
      )
      // 時刻の修正は体重記録の控えだけを指すので、控えの種類では絞らない。絞ると、控えの種類の索引から引く計画になり、直した時刻の索引を使わない
      .where(
        and(
          gte(weightRecordMeasuredAtCorrections.measuredAt, from),
          lt(weightRecordMeasuredAtCorrections.measuredAt, to),
        ),
      );
    const latestMeasuredAts = findLatestMeasuredAtCorrections(
      db,
      or(
        inArray(syncWriteReceipts.recordId, createdInRange),
        inArray(syncWriteReceipts.recordId, correctedInRange),
      ),
    );
    return sortByMeasuredAt(
      db
        .select({
          id: weightRecords.id,
          measuredAt: weightRecords.measuredAt,
          timeZone: weightRecords.timeZone,
        })
        .from(weightRecords)
        .where(
          or(
            inArray(weightRecords.id, createdInRange),
            inArray(weightRecords.id, correctedInRange),
          ),
        )
        .all()
        .map((record) => ({ id: record.id, ...(latestMeasuredAts.get(record.id) ?? record) }))
        .filter(({ measuredAt }) => measuredAt >= from && measuredAt < to),
    );
  },
  existsImportedSample: (healthkitSampleUuid) =>
    db
      .select({ weightRecordId: importedWeightRecords.weightRecordId })
      .from(importedWeightRecords)
      .where(eq(importedWeightRecords.healthkitSampleUuid, healthkitSampleUuid))
      .all().length > 0,
  hasDeletion: (recordId) =>
    db
      .select({ id: weightRecordDeletions.syncWriteReceiptId })
      .from(weightRecordDeletions)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, weightRecordDeletions.syncWriteReceiptId),
      )
      .where(isReceiptOfRecord(recordId))
      .all().length > 0,
  hasCorrection: (id) =>
    [weightRecordWeightCorrections, weightRecordMeasuredAtCorrections].some(
      (corrections: CorrectionTable) =>
        db
          .select({ id: corrections.syncWriteReceiptId })
          .from(corrections)
          .innerJoin(syncWriteReceipts, eq(syncWriteReceipts.id, corrections.syncWriteReceiptId))
          .where(isReceiptOfRecord(id))
          .get() !== undefined,
    ),
  insert: ({ id, weightKg, measuredAt, timeZone, imported }) => {
    db.insert(weightRecords).values({ id, weightKg, measuredAt, timeZone }).run();
    if (imported === undefined) {
      return;
    }
    db.insert(importedWeightRecords)
      .values({
        weightRecordId: id,
        sourceAppName: imported.sourceAppName,
        sourceBundleId: imported.sourceBundleId,
        healthkitSampleUuid: imported.healthkitSampleUuid,
      })
      .run();
    if (imported.bodyFat === undefined) {
      return;
    }
    db.insert(importedBodyFatPercentages)
      .values({
        weightRecordId: id,
        bodyFatPercentage: imported.bodyFat.percentage,
        healthkitSampleUuid: imported.bodyFat.healthkitSampleUuid,
      })
      .run();
  },
  insertWeightCorrection: (receiptId, weightKg) => {
    db.insert(weightRecordWeightCorrections)
      .values({ syncWriteReceiptId: receiptId.value, weightKg })
      .run();
  },
  insertMeasuredAtCorrection: (receiptId, { measuredAt, timeZone }) => {
    db.insert(weightRecordMeasuredAtCorrections)
      .values({ syncWriteReceiptId: receiptId.value, measuredAt, timeZone })
      .run();
  },
  remove: (id) => {
    db.delete(weightRecords).where(eq(weightRecords.id, id)).run();
  },
  insertDeletion: (receiptId) => {
    db.insert(weightRecordDeletions).values({ syncWriteReceiptId: receiptId.value }).run();
  },
});

const isReceiptOfRecord = (recordId: RecordId) =>
  and(eq(syncWriteReceipts.recordType, "weight_record"), eq(syncWriteReceipts.recordId, recordId));

// 版は列に持たず、当てた直す書き込みの控えから数える。今の値と同じで何も書かなかった直し（unchanged）も、控えは applied なので数える
const countVersion = (db: DrizzleSqliteDODatabase, id: RecordId): number =>
  1 +
  (db
    .select({ total: count() })
    .from(syncWriteReceipts)
    .where(
      and(
        isReceiptOfRecord(id),
        eq(syncWriteReceipts.kind, "update"),
        eq(syncWriteReceipts.result, "applied"),
      ),
    )
    .get()?.total ?? 0);

// 記録ごとの、受け取った順でいちばんあとの体重の修正。receiptFilter で読む記録を絞れる。
// 修正の表は体重記録の控えだけを指すので、控えの種類では絞らない。
// 種類で絞ると控えの種類の索引から、通し番号で並べると変更の並びから引く計画になり、どちらも修正の数でなく記録や変更の数だけなめる。
// そのため、修正の表から引き、いちばんあとの通し番号はアプリで選ぶ
const findLatestWeightCorrections = (
  db: DrizzleSqliteDODatabase,
  receiptFilter?: SQL,
): Map<RecordId, number> =>
  pickLatestByRecord(
    db
      .select({
        recordId: syncWriteReceipts.recordId,
        sequence: syncWriteRecordChanges.recordChangeSequence,
        value: weightRecordWeightCorrections.weightKg,
      })
      .from(weightRecordWeightCorrections)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, weightRecordWeightCorrections.syncWriteReceiptId),
      )
      .innerJoin(
        syncWriteRecordChanges,
        eq(
          syncWriteRecordChanges.syncWriteReceiptId,
          weightRecordWeightCorrections.syncWriteReceiptId,
        ),
      )
      .where(receiptFilter)
      .all(),
  );

// 記録ごとの、受け取った順でいちばんあとの時刻の修正。時刻とタイムゾーンは組で引く。引き方は体重の修正と同じ
const findLatestMeasuredAtCorrections = (
  db: DrizzleSqliteDODatabase,
  receiptFilter?: SQL,
): Map<RecordId, Pick<WeightRecord, "measuredAt" | "timeZone">> =>
  pickLatestByRecord(
    db
      .select({
        recordId: syncWriteReceipts.recordId,
        sequence: syncWriteRecordChanges.recordChangeSequence,
        value: {
          measuredAt: weightRecordMeasuredAtCorrections.measuredAt,
          timeZone: weightRecordMeasuredAtCorrections.timeZone,
        },
      })
      .from(weightRecordMeasuredAtCorrections)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, weightRecordMeasuredAtCorrections.syncWriteReceiptId),
      )
      .innerJoin(
        syncWriteRecordChanges,
        eq(
          syncWriteRecordChanges.syncWriteReceiptId,
          weightRecordMeasuredAtCorrections.syncWriteReceiptId,
        ),
      )
      .where(receiptFilter)
      .all(),
  );

// 修正の行から、記録ごとに通し番号がいちばん大きい行の値を選ぶ
const pickLatestByRecord = <T>(
  rows: readonly { recordId: RecordId; sequence: number; value: T }[],
): Map<RecordId, T> => {
  const latest = new Map<RecordId, { sequence: number; value: T }>();
  for (const row of rows) {
    const current = latest.get(row.recordId);
    if (current === undefined || row.sequence > current.sequence) {
      latest.set(row.recordId, row);
    }
  }
  return new Map([...latest].map(([recordId, { value }]) => [recordId, value]));
};

const sortByMeasuredAt = <T extends { measuredAt: Date }>(records: T[]): T[] =>
  records.toSorted((a, b) => a.measuredAt.getTime() - b.measuredAt.getTime());

const toWeightRecord = ({
  imported,
  bodyFat,
  current,
  record,
  version,
}: {
  record: typeof weightRecords.$inferSelect;
  imported: typeof importedWeightRecords.$inferSelect | null;
  bodyFat: typeof importedBodyFatPercentages.$inferSelect | null;
  current: Pick<WeightRecord, "weightKg" | "measuredAt" | "timeZone">;
  version: number;
}): WeightRecord => ({
  id: record.id,
  ...current,
  version,
  imported:
    imported === null
      ? undefined
      : {
          sourceAppName: imported.sourceAppName,
          sourceBundleId: imported.sourceBundleId,
          healthkitSampleUuid: imported.healthkitSampleUuid,
          bodyFat:
            bodyFat === null
              ? undefined
              : {
                  percentage: bodyFat.bodyFatPercentage,
                  healthkitSampleUuid: bodyFat.healthkitSampleUuid,
                },
        },
});
