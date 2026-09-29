import { match } from "ts-pattern";
import { computeCalendarDay } from "./compute-calendar-day";
import { isTimeZoneName } from "./is-time-zone-name";
import { isWithinAcceptedRange } from "./is-within-accepted-range";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { SyncWrite } from "./sync-write";
import type { SyncWriteOutcome } from "./sync-write-outcome";
import type { WeightRecord } from "./weight-record";

export const applySyncWrites = (
  store: SyncStore,
  request: {
    clientState: SyncClientState;
    writes: readonly SyncWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  },
): { writeId: string; outcome: SyncWriteOutcome }[] =>
  store.transaction(() => {
    const requestLogId = crypto.randomUUID();
    store.insertPushRequestLog({
      id: requestLogId,
      receivedAt: request.receivedAt,
      clientState: request.clientState,
      isFinalBatch: request.isFinalBatch,
    });
    const startedOn = store.findStartedOn();
    return request.writes.map((write, positionInRequest) => {
      const previousOutcome = store.findWriteOutcome(write.id);
      if (previousOutcome !== undefined) {
        return { writeId: write.id, outcome: previousOutcome };
      }
      const { kind, recordId, outcome } = match(write)
        .with({ type: "create_weight_record" }, ({ weightRecord }) => ({
          kind: "create" as const,
          recordId: weightRecord.id,
          outcome: applyCreateWeightRecord(store, weightRecord),
        }))
        .with({ type: "update_weight_record" }, ({ weightRecord }) => ({
          kind: "update" as const,
          recordId: weightRecord.id,
          outcome: applyUpdateWeightRecord(store, startedOn, weightRecord),
        }))
        .with({ type: "source_deleted_weight_record" }, ({ weightRecordId }) => ({
          kind: "source_deleted" as const,
          recordId: weightRecordId,
          outcome: applySourceDeletedWeightRecord(store, weightRecordId),
        }))
        .exhaustive();
      store.insertWriteReceipt({
        writeId: write.id,
        requestLogId,
        positionInRequest,
        kind,
        recordType: "weight_record",
        recordId,
        outcome,
      });
      // 削除の印は書き込みの控えを指すので、控えを書いたあとに足す
      if (write.type === "source_deleted_weight_record" && outcome.result === "applied") {
        store.insertWeightRecordDeletion(write.id);
      }
      if (outcome.result === "applied" || outcome.result === "ignored_tombstone") {
        store.insertRecordChange({ recordType: "weight_record", recordId, writeId: write.id });
      }
      return { writeId: write.id, outcome };
    });
  });

const applyCreateWeightRecord = (
  store: SyncStore,
  weightRecord: Omit<WeightRecord, "version">,
): SyncWriteOutcome => {
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return { result: "rejected", reason: "out_of_range" };
  }
  const bodyFat = weightRecord.imported?.bodyFat;
  if (bodyFat !== undefined && !isWithinAcceptedRange("bodyFatPercentage", bodyFat.percentage)) {
    return { result: "rejected", reason: "out_of_range" };
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return { result: "rejected", reason: "invalid_time_zone" };
  }
  if (store.existsWeightRecordDeletion(weightRecord.id)) {
    return { result: "ignored_tombstone" };
  }
  // ID の出し方に頼らず、同じサンプルを二重に取り込まない
  const isDuplicate =
    store.findWeightRecord(weightRecord.id) !== undefined ||
    (weightRecord.imported !== undefined &&
      store.existsImportedSample(weightRecord.imported.healthkitSampleUuid));
  if (isDuplicate) {
    return { result: "ignored_duplicate" };
  }
  store.insertWeightRecord({ ...weightRecord, version: 1 });
  return { result: "applied" };
};

const applyUpdateWeightRecord = (
  store: SyncStore,
  startedOn: string | undefined,
  weightRecord: Omit<WeightRecord, "imported">,
): SyncWriteOutcome => {
  // 版を上げ忘れる不具合が、受け付けなかった1件として見えるようにする
  if (weightRecord.version < 2) {
    return { result: "rejected", reason: "version_too_low" };
  }
  if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
    return { result: "rejected", reason: "out_of_range" };
  }
  if (!isTimeZoneName(weightRecord.timeZone)) {
    return { result: "rejected", reason: "invalid_time_zone" };
  }
  if (store.existsWeightRecordDeletion(weightRecord.id)) {
    return { result: "ignored_tombstone" };
  }
  const current = store.findWeightRecord(weightRecord.id);
  if (current === undefined) {
    return { result: "rejected", reason: "record_not_found" };
  }
  if (
    startedOn !== undefined &&
    computeCalendarDay(current.measuredAt, current.timeZone) < startedOn
  ) {
    return { result: "rejected", reason: "record_before_started_on" };
  }
  // 2台で同じ記録を直したとき、あとに受け取ったほうの版が前より小さくならないようにする
  store.updateWeightRecord(weightRecord.id, {
    weightKg: weightRecord.weightKg,
    measuredAt: weightRecord.measuredAt,
    timeZone: weightRecord.timeZone,
    version: Math.max(weightRecord.version, current.version + 1),
  });
  return { result: "applied" };
};

const applySourceDeletedWeightRecord = (
  store: SyncStore,
  weightRecordId: string,
): SyncWriteOutcome => {
  if (store.existsWeightRecordDeletion(weightRecordId)) {
    return { result: "ignored_tombstone" };
  }
  const current = store.findWeightRecord(weightRecordId);
  if (current !== undefined && current.version >= 2) {
    return { result: "kept_corrected" };
  }
  // 記録がまだ届いていなくても印を残し、あとから届く作る書き込みで生き返らせない
  if (current !== undefined) {
    store.deleteWeightRecord(weightRecordId);
  }
  return { result: "applied" };
};
