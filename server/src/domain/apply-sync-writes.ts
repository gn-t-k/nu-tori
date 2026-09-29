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
    const rejectedWrites: Extract<UsageEvent, { name: "sync_write_rejected" }>[] = [];
    const results = request.writes.map((write, positionInRequest) => {
      const previousOutcome = store.findWriteOutcome(write.id);
      if (previousOutcome !== undefined) {
        return { writeId: write.id, outcome: previousOutcome };
      }
      const { kind, outcome } = match(write)
        .with({ type: "create_weight_record" }, ({ weightRecord }) => ({
          kind: "create" as const,
          outcome: applyCreateWeightRecord(store, weightRecord),
        }))
        .with({ type: "update_weight_record" }, ({ weightRecord }) => ({
          kind: "update" as const,
          outcome: applyUpdateWeightRecord(store, startedOn, weightRecord),
        }))
        .exhaustive();
      store.insertWriteReceipt({
        writeId: write.id,
        requestLogId,
        positionInRequest,
        kind,
        recordType: "weight_record",
        recordId: write.weightRecord.id,
        outcome,
      });
      if (outcome.result === "applied") {
        store.insertRecordChange({
          recordType: "weight_record",
          recordId: write.weightRecord.id,
          writeId: write.id,
        });
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
