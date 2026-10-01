import { match } from "ts-pattern";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { WriteKind } from "../../domain/sync-ledger/write-kind";
import type { SyncWriteOutcome } from "../../domain/sync-write-outcome";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { WeightRecord } from "./weight-record";
import type { WeightRecordStore } from "./weight-record-store";
import { type WeightRecordWrite, weightRecordWriteTypes } from "./weight-record-write";

// 使い始めた日より前の日付の記録は、直す書き込みを受け付けない
export const createWeightRecordKind = (
  store: WeightRecordStore,
  findStartedOn: () => string | undefined,
): RecordKind<"weight_record", WeightRecordWrite, WeightRecord> => ({
  name: "weight_record",
  writes: {
    isWrite: (write): write is WeightRecordWrite => weightRecordWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_weight_record" }, ({ weightRecord }) =>
          decideCreate(store, weightRecord),
        )
        .with({ type: "update_weight_record" }, ({ weightRecord }) =>
          decideUpdate(store, findStartedOn, weightRecord),
        )
        .with({ type: "source_deleted_weight_record" }, ({ weightRecordId }) =>
          decideSourceDeleted(store, weightRecordId),
        )
        .exhaustive(),
  },
  readCurrent: (recordId): CurrentRecord<WeightRecord> => {
    const weightRecord = store.find(recordId);
    if (weightRecord !== undefined) {
      return { status: "value", value: weightRecord };
    }
    return store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});

const decideCreate = (
  store: WeightRecordStore,
  weightRecord: Omit<WeightRecord, "version">,
): WriteDecision => {
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return settled("create", weightRecord.id, { result: "rejected", reason: "out_of_range" });
  }
  const bodyFat = weightRecord.imported?.bodyFat;
  if (bodyFat !== undefined && !isWithinAcceptedRange("bodyFatPercentage", bodyFat.percentage)) {
    return settled("create", weightRecord.id, { result: "rejected", reason: "out_of_range" });
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return settled("create", weightRecord.id, { result: "rejected", reason: "invalid_time_zone" });
  }
  if (store.hasDeletion(weightRecord.id)) {
    return settled("create", weightRecord.id, { result: "ignored_tombstone" });
  }
  // ID の出し方に頼らず、同じサンプルを二重に取り込まない
  const isDuplicate =
    store.find(weightRecord.id) !== undefined ||
    (weightRecord.imported !== undefined &&
      store.existsImportedSample(weightRecord.imported.healthkitSampleUuid));
  if (isDuplicate) {
    return settled("create", weightRecord.id, { result: "ignored_duplicate" });
  }
  return applied("create", weightRecord.id, () => {
    store.insert({ ...weightRecord, version: 1 });
  });
};

const decideUpdate = (
  store: WeightRecordStore,
  findStartedOn: () => string | undefined,
  weightRecord: Omit<WeightRecord, "imported">,
): WriteDecision => {
  // 版を上げ忘れる不具合が、受け付けなかった1件として見えるようにする
  if (weightRecord.version < 2) {
    return settled("update", weightRecord.id, { result: "rejected", reason: "version_too_low" });
  }
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return settled("update", weightRecord.id, { result: "rejected", reason: "out_of_range" });
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return settled("update", weightRecord.id, { result: "rejected", reason: "invalid_time_zone" });
  }
  if (store.hasDeletion(weightRecord.id)) {
    return settled("update", weightRecord.id, { result: "ignored_tombstone" });
  }
  const current = store.find(weightRecord.id);
  if (current === undefined) {
    return settled("update", weightRecord.id, { result: "rejected", reason: "record_not_found" });
  }
  const startedOn = findStartedOn();
  if (
    startedOn !== undefined &&
    computeCalendarDayInTimeZone(current.measuredAt, current.timeZone) < startedOn
  ) {
    return settled("update", weightRecord.id, {
      result: "rejected",
      reason: "record_before_started_on",
    });
  }
  return applied("update", weightRecord.id, () => {
    // 2台で同じ記録を直したとき、あとに受け取ったほうの版が前より小さくならないようにする
    store.update(weightRecord.id, {
      weightKg: weightRecord.weightKg,
      measuredAt: weightRecord.measuredAt,
      timeZone: weightRecord.timeZone,
      version: Math.max(weightRecord.version, current.version + 1),
    });
  });
};

const decideSourceDeleted = (store: WeightRecordStore, weightRecordId: string): WriteDecision => {
  if (store.hasDeletion(weightRecordId)) {
    return settled("source_deleted", weightRecordId, { result: "ignored_tombstone" });
  }
  const current = store.find(weightRecordId);
  if (current !== undefined && current.version >= 2) {
    return settled("source_deleted", weightRecordId, { result: "kept_corrected" });
  }
  // 記録がまだ届いていなくても印を残し、あとから届く作る書き込みで生き返らせない
  return applied("source_deleted", weightRecordId, (receiptId) => {
    if (current !== undefined) {
      store.remove(weightRecordId);
    }
    store.insertDeletion(receiptId);
  });
};

// 行を書かずに終わる。削除の印で捨てたときだけ、変更の並びに載せる
const settled = (
  writeKind: WriteKind,
  recordId: string,
  outcome: Exclude<SyncWriteOutcome, { result: "applied" }>,
): WriteDecision => ({
  writeKind,
  recordId,
  outcome,
  changedRecordId: outcome.result === "ignored_tombstone" ? recordId : undefined,
  addedChanges: [],
  commit: () => undefined,
});

const applied = (
  writeKind: WriteKind,
  recordId: string,
  commit: WriteDecision["commit"],
): WriteDecision => ({
  writeKind,
  recordId,
  outcome: { result: "applied" },
  changedRecordId: recordId,
  addedChanges: [],
  commit,
});
