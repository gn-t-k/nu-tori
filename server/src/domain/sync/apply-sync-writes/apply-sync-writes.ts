import { match, P } from "ts-pattern";
import { computeCalendarDay } from "../../compute-calendar-day";
import { isTimeZoneName } from "../../is-time-zone-name";
import { isWithinAcceptedRange } from "../../is-within-accepted-range";
import type { AccountSettings } from "../account-settings";
import type { RecordType } from "../record-type";
import type { SyncClientState } from "../sync-client-state";
import type { SyncStore } from "../sync-store";
import type { SyncWrite } from "../sync-write";
import type { SyncWriteOutcome } from "../sync-write-outcome";
import type { UsageEvent } from "../usage-event";
import { computeUsageEvents } from "../compute-usage-events";

// 書き込みを要求の中の順に、1つのトランザクションで当てる。結果は書き込みごとに返し、受け付けない書き込みがあってもほかは当てる
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
      const { kind, recordType, recordId, outcome, changedRecordId } = applyWrite(
        store,
        startedOn,
        write,
      );
      store.insertWriteReceipt({
        writeId: write.id,
        requestLogId,
        positionInRequest,
        kind,
        recordType,
        recordId,
        outcome,
      });
      if (write.type === "update_account_settings") {
        store.insertAccountSettingChange({
          writeId: write.id,
          sendsUsageData: write.accountSettings.sendsUsageData,
        });
      }
      if (changedRecordId !== undefined) {
        store.insertRecordChange({ recordType, recordId: changedRecordId, writeId: write.id });
      }
      if (outcome.result === "rejected") {
        rejectedWrites.push({
          name: "sync_write_rejected",
          writeKind: kind,
          recordType,
          reason: outcome.reason,
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

type AppliedWrite = {
  kind: "create" | "update";
  recordType: RecordType;
  recordId: string;
  outcome: SyncWriteOutcome;
  changedRecordId: string | undefined;
};

const applyWrite = (
  store: SyncStore,
  startedOn: string | undefined,
  write: SyncWrite,
): AppliedWrite =>
  match(write)
    .with(
      { type: P.union("create_weight_record", "update_weight_record") },
      (weightWrite): AppliedWrite => {
        const outcome = applyWeightRecordWrite(store, startedOn, weightWrite);
        return {
          kind: weightWrite.type === "create_weight_record" ? "create" : "update",
          recordType: "weight_record",
          recordId: weightWrite.weightRecord.id,
          outcome,
          changedRecordId: outcome.result === "applied" ? weightWrite.weightRecord.id : undefined,
        };
      },
    )
    .with({ type: "update_account_settings" }, ({ accountSettings }): AppliedWrite => ({
      kind: "update",
      recordType: "account_settings",
      recordId: accountSettings.id,
      outcome: { result: "applied" },
      changedRecordId: applyAccountSettingsWrite(store, accountSettings),
    }))
    .exhaustive();

const applyAccountSettingsWrite = (store: SyncStore, accountSettings: AccountSettings): string => {
  const current = store.findAccountSettings();
  if (current === undefined) {
    store.insertAccountSettings(accountSettings);
  } else {
    store.updateAccountSettings(accountSettings.sendsUsageData);
  }
  return current?.id ?? accountSettings.id;
};

const applyWeightRecordWrite = (
  store: SyncStore,
  startedOn: string | undefined,
  write: Extract<SyncWrite, { type: "create_weight_record" | "update_weight_record" }>,
): SyncWriteOutcome =>
  match(write)
    .with({ type: "create_weight_record" }, ({ weightRecord }): SyncWriteOutcome => {
      if (!isWithinAcceptedRange("weightKilograms", weightRecord.weightKg)) {
        return { result: "rejected", reason: "out_of_range" };
      }
      const bodyFat = weightRecord.imported?.bodyFat;
      if (
        bodyFat !== undefined &&
        !isWithinAcceptedRange("bodyFatPercentage", bodyFat.percentage)
      ) {
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
    })
    .with({ type: "update_weight_record" }, ({ weightRecord }): SyncWriteOutcome => {
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
    })
    .exhaustive();
