import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import { rejectWrite } from "../../domain/sync-ledger/reject-write";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import type { WeightRecord } from "./weight-record";
import type { WeightRecordStore } from "./weight-record-store";
import { type WeightRecordWrite, weightRecordWriteTypes } from "./weight-record-write";

// 使い始めた日より前の日付の記録は、直す書き込みを受け付けない
export const createWeightRecordKind = (
  dependencies: Dependencies,
): RecordKind<"weight_record", WeightRecordWrite, WeightRecord> => ({
  name: "weight_record",
  writes: {
    isWrite: (write): write is WeightRecordWrite => weightRecordWriteTypes.includes(write.type),
    decide: (write) =>
      match(write)
        .with({ type: "create_weight_record" }, ({ weightRecord }) =>
          decideCreate(dependencies, weightRecord),
        )
        .with({ type: "update_weight_record" }, ({ weightRecord }) =>
          decideUpdate(dependencies, weightRecord),
        )
        .with({ type: "source_deleted_weight_record" }, ({ weightRecordId }) =>
          decideSourceDeleted(dependencies, weightRecordId),
        )
        .exhaustive(),
  },
  follows: undefined,
  whenGone: "deletion_mark",
  readCurrent: (recordId): CurrentRecord<WeightRecord> => {
    const weightRecord = dependencies.store.find(recordId);
    if (weightRecord !== undefined) {
      return { status: "value", value: weightRecord };
    }
    return dependencies.store.hasDeletion(recordId) ? { status: "deleted" } : { status: "absent" };
  },
});

type Dependencies = {
  store: WeightRecordStore;
  findStartedOn: () => string | undefined;
};

const decideCreate = (
  dependencies: Dependencies,
  weightRecord: Omit<WeightRecord, "version">,
): WriteDecision => {
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return rejectWrite("create", weightRecord.id, "out_of_range");
  }
  const bodyFat = weightRecord.imported?.bodyFat;
  if (bodyFat !== undefined && !isWithinAcceptedRange("bodyFatPercentage", bodyFat.percentage)) {
    return rejectWrite("create", weightRecord.id, "out_of_range");
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return rejectWrite("create", weightRecord.id, "invalid_time_zone");
  }
  const { store } = dependencies;
  if (store.hasDeletion(weightRecord.id)) {
    return { result: "ignored_tombstone", writeKind: "create", recordId: weightRecord.id };
  }
  // ID の出し方に頼らず、同じサンプルを二重に取り込まない
  const isDuplicate =
    store.find(weightRecord.id) !== undefined ||
    (weightRecord.imported !== undefined &&
      store.existsImportedSample(weightRecord.imported.healthkitSampleUuid));
  if (isDuplicate) {
    return { result: "ignored_duplicate", writeKind: "create", recordId: weightRecord.id };
  }
  return {
    result: "applied",
    writeKind: "create",
    recordId: weightRecord.id,
    addedChanges: [],
    usageEvents: [],
    commit: () => {
      store.insert({ ...weightRecord, version: 1 });
    },
  };
};

const decideUpdate = (
  dependencies: Dependencies,
  weightRecord: Omit<WeightRecord, "imported">,
): WriteDecision => {
  // 版を上げ忘れる不具合が、受け付けなかった1件として見えるようにする
  if (weightRecord.version < 2) {
    return rejectWrite("update", weightRecord.id, "version_too_low");
  }
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return rejectWrite("update", weightRecord.id, "out_of_range");
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return rejectWrite("update", weightRecord.id, "invalid_time_zone");
  }
  const { store } = dependencies;
  if (store.hasDeletion(weightRecord.id)) {
    return { result: "ignored_tombstone", writeKind: "update", recordId: weightRecord.id };
  }
  const current = store.find(weightRecord.id);
  if (current === undefined) {
    return rejectWrite("update", weightRecord.id, "record_not_found");
  }
  const startedOn = dependencies.findStartedOn();
  if (
    startedOn !== undefined &&
    computeCalendarDayInTimeZone(current.measuredAt, current.timeZone) < startedOn
  ) {
    return rejectWrite("update", weightRecord.id, "record_before_started_on");
  }
  return {
    result: "applied",
    writeKind: "update",
    recordId: weightRecord.id,
    addedChanges: [],
    usageEvents: [],
    commit: () => {
      // 2台で同じ記録を直したとき、あとに受け取ったほうの版が前より小さくならないようにする
      store.update(weightRecord.id, {
        weightKg: weightRecord.weightKg,
        measuredAt: weightRecord.measuredAt,
        timeZone: weightRecord.timeZone,
        version: Math.max(weightRecord.version, current.version + 1),
      });
    },
  };
};

const decideSourceDeleted = (
  dependencies: Dependencies,
  weightRecordId: RecordId,
): WriteDecision => {
  const { store } = dependencies;
  if (store.hasDeletion(weightRecordId)) {
    return { result: "ignored_tombstone", writeKind: "source_deleted", recordId: weightRecordId };
  }
  const current = store.find(weightRecordId);
  if (current !== undefined && current.version >= 2) {
    return { result: "kept_corrected", writeKind: "source_deleted", recordId: weightRecordId };
  }
  // 記録がまだ届いていなくても印を残し、あとから届く作る書き込みで生き返らせない
  return {
    result: "applied",
    writeKind: "source_deleted",
    recordId: weightRecordId,
    addedChanges: [],
    usageEvents: [],
    commit: (receiptId) => {
      if (current !== undefined) {
        store.remove(weightRecordId);
      }
      store.insertDeletion(receiptId);
    },
  };
};
