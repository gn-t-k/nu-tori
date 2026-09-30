import { match } from "ts-pattern";
import type { createRecordKinds } from "./create-record-kinds";
import type { AccountSettings } from "../account-settings/domain/account-settings";
import { computeCalendarDay } from "./compute-calendar-day";
import { computeUsageEvents } from "./compute-usage-events";
import { isTimeZoneName } from "./is-time-zone-name";
import { isWithinAcceptedRange } from "../weight-record/domain/is-within-accepted-range";
import type { RecordType } from "./record-type";
import type { RegisteredRecordType } from "./sync-change";
import { createSyncLedger, type RejectedWrite } from "./sync-ledger/sync-ledger";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { SyncWrite } from "./sync-write";
import type {
  CreateWeightRecordOutcome,
  SourceDeletedWeightRecordOutcome,
  SyncWriteOutcome,
  UpdateWeightRecordOutcome,
} from "./sync-write-outcome";
import type { UsageEvent } from "./usage-event";
import type { WeightRecord } from "../weight-record/domain/weight-record";

export const applySyncWrites = (
  store: SyncStore,
  kinds: ReturnType<typeof createRecordKinds>,
  request: {
    clientState: SyncClientState;
    writes: readonly SyncWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  },
): {
  results: { writeId: string; outcome: SyncWriteOutcome }[];
  usageEvents: UsageEvent[];
} => {
  const ledger = createSyncLedger<RecordType, RegisteredRecordType, SyncWrite, unknown>(
    store,
    kinds,
  );
  const startedOn = store.findStartedOn();
  const pushed = ledger.push(request, (write, position) =>
    applyLegacyWrite(store, startedOn, write, position),
  );
  return {
    results: pushed.results,
    usageEvents: computeUsageEvents(store, {
      clientState: request.clientState,
      receivedAt: request.receivedAt,
      previousRequestReceivedAt: pushed.previousRequestReceivedAt,
      rejectedWrites: pushed.rejectedWrites.map((rejected) => ({
        name: "sync_write_rejected",
        ...rejected,
      })),
    }),
  };
};

// 登録簿にない種類の書き込みを、今の道で当てる。冪等は帳簿が見る
const applyLegacyWrite = (
  store: SyncStore,
  startedOn: string | undefined,
  write: SyncWrite,
  position: { requestLogId: string; positionInRequest: number },
): { outcome: SyncWriteOutcome; rejection: RejectedWrite<RecordType> | undefined } => {
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
  const { recordType } = applied;
  store.insertWriteReceipt({
    writeId: write.id,
    requestLogId: position.requestLogId,
    positionInRequest: position.positionInRequest,
    kind: applied.kind,
    recordType: applied.recordType,
    recordId: applied.recordId,
    outcome: applied.outcome,
  });
  // 削除の印は書き込みの控えを指すので、控えを書いたあとに足す
  if (applied.kind === "source_deleted" && applied.outcome.result === "applied") {
    store.insertWeightRecordDeletion(write.id);
  }
  const changedRecordId = match(applied)
    .with({ recordType: "weight_record" }, (weightWrite) =>
      weightWrite.outcome.result === "applied" || weightWrite.outcome.result === "ignored_tombstone"
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
  const rejection: RejectedWrite<RecordType> | undefined =
    applied.outcome.result === "rejected" &&
    applied.recordType === "weight_record" &&
    applied.kind !== "source_deleted"
      ? {
          writeKind: applied.kind,
          recordType: applied.recordType,
          reason: applied.outcome.reason,
        }
      : undefined;
  return { outcome: applied.outcome, rejection };
};

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
