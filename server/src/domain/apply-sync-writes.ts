import { match } from "ts-pattern";
import type { AccountSettings } from "./account-settings";
import { computeCalendarDay } from "./compute-calendar-day";
import { computeUsageEvents } from "./compute-usage-events";
import { isTimeZoneName } from "./is-time-zone-name";
import { isWithinAcceptedRange } from "./is-within-accepted-range";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { SyncWrite } from "./sync-write";
import type { SyncWriteOutcome } from "./sync-write-outcome";
import type { UsageEvent } from "./usage-event";
import type { WeightRecord } from "./weight-record";

export const applySyncWrites = (
  store: SyncStore,
  request: {
    clientState: SyncClientState;
    writes: readonly SyncWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  },
): {
  results: { writeId: string; outcome: SyncWriteOutcome }[];
  usageEvents: UsageEvent[];
} =>
  store.transaction(() => {
    const requestLogId = crypto.randomUUID();
    const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
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
      const applied = match(write)
        .with({ type: "create_weight_record" }, ({ weightRecord }): AppliedWrite => ({
          kind: "create",
          recordType: "weight_record",
          recordId: weightRecord.id,
          outcome: applyCreateWeightRecord(store, weightRecord),
        }))
        .with({ type: "update_weight_record" }, ({ weightRecord }): AppliedWrite => ({
          kind: "update",
          recordType: "weight_record",
          recordId: weightRecord.id,
          outcome: applyUpdateWeightRecord(store, startedOn, weightRecord),
        }))
        .with({ type: "source_deleted_weight_record" }, ({ weightRecordId }): AppliedWrite => ({
          kind: "source_deleted",
          recordType: "weight_record",
          recordId: weightRecordId,
          outcome: applySourceDeletedWeightRecord(store, weightRecordId),
        }))
        .with({ type: "update_account_settings" }, ({ accountSettings }): AppliedWrite => ({
          kind: "update",
          recordType: "account_settings",
          recordId: accountSettings.id,
          outcome: { result: "applied" },
          storedRecordId: applyAccountSettings(store, accountSettings),
          sendsUsageData: accountSettings.sendsUsageData,
        }))
        .exhaustive();
      const { recordType, outcome } = applied;
      match(applied)
        .with({ recordType: "weight_record" }, (weightWrite) => {
          store.insertWriteReceipt({
            writeId: write.id,
            requestLogId,
            positionInRequest,
            kind: weightWrite.kind,
            recordType: weightWrite.recordType,
            recordId: weightWrite.recordId,
            outcome: weightWrite.outcome,
          });
        })
        .with({ recordType: "account_settings" }, (settingsWrite) => {
          store.insertWriteReceipt({
            writeId: write.id,
            requestLogId,
            positionInRequest,
            kind: settingsWrite.kind,
            recordType: settingsWrite.recordType,
            recordId: settingsWrite.recordId,
            outcome: settingsWrite.outcome,
          });
        })
        .exhaustive();
      // 削除の印は書き込みの控えを指すので、控えを書いたあとに足す
      if (applied.kind === "source_deleted" && applied.outcome.result === "applied") {
        store.insertWeightRecordDeletion(write.id);
      }
      const changedRecordId = match(applied)
        .with({ recordType: "weight_record" }, (weightWrite) =>
          weightWrite.outcome.result === "applied" ||
          weightWrite.outcome.result === "ignored_tombstone"
            ? weightWrite.recordId
            : undefined,
        )
        .with({ recordType: "account_settings" }, (settingsWrite) => {
          store.insertAccountSettingChange({
            writeId: write.id,
            sendsUsageData: settingsWrite.sendsUsageData,
          });
          return settingsWrite.storedRecordId;
        })
        .exhaustive();
      if (changedRecordId !== undefined) {
        store.insertRecordChange({ recordType, recordId: changedRecordId, writeId: write.id });
      }
      if (
        applied.recordType === "weight_record" &&
        applied.kind !== "source_deleted" &&
        applied.outcome.result === "rejected"
      ) {
        rejectedWrites.push({
          name: "sync_write_rejected",
          writeKind: applied.kind,
          recordType: applied.recordType,
          reason: applied.outcome.reason,
        });
      }
      return { writeId: write.id, outcome };
    });
    return {
      results,
      usageEvents: computeUsageEvents(store, {
        clientState: request.clientState,
        receivedAt: request.receivedAt,
        previousRequestReceivedAt,
        rejectedWrites,
      }),
    };
  });

type AppliedWrite =
  | {
      kind: "create";
      recordType: "weight_record";
      recordId: string;
      outcome: CreateWeightRecordOutcome;
    }
  | {
      kind: "update";
      recordType: "weight_record";
      recordId: string;
      outcome: UpdateWeightRecordOutcome;
    }
  | {
      kind: "source_deleted";
      recordType: "weight_record";
      recordId: string;
      outcome: SourceDeletedWeightRecordOutcome;
    }
  | {
      kind: "update";
      recordType: "account_settings";
      recordId: string;
      outcome: { result: "applied" };
      storedRecordId: string;
      sendsUsageData: boolean;
    };

type CreateWeightRecordOutcome =
  | { result: "applied" | "ignored_duplicate" | "ignored_tombstone" }
  | { result: "rejected"; reason: "out_of_range" | "invalid_time_zone" };

type UpdateWeightRecordOutcome =
  | { result: "applied" | "ignored_tombstone" }
  | {
      result: "rejected";
      reason:
        | "out_of_range"
        | "invalid_time_zone"
        | "version_too_low"
        | "record_not_found"
        | "record_before_started_on";
    };

type SourceDeletedWeightRecordOutcome = {
  result: "applied" | "ignored_tombstone" | "kept_corrected";
};

const applyAccountSettings = (store: SyncStore, accountSettings: AccountSettings): string => {
  const current = store.findAccountSettings();
  if (current === undefined) {
    store.insertAccountSettings(accountSettings);
  } else {
    store.updateAccountSettings(accountSettings.sendsUsageData);
  }
  return current?.id ?? accountSettings.id;
};

const applyCreateWeightRecord = (
  store: SyncStore,
  weightRecord: Omit<WeightRecord, "version">,
): CreateWeightRecordOutcome => {
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
): UpdateWeightRecordOutcome => {
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
): SourceDeletedWeightRecordOutcome => {
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
