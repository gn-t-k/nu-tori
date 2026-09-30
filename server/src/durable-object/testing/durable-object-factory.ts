import { composeFactory, defineFactory } from "@praha/drizzle-factory";
import { durableObjectTables } from "../durable-object-tables";

const schema = durableObjectTables;

const firstSignIns = defineFactory({
  schema,
  table: "firstSignIns",
  resolver: ({ sequence }) => ({
    id: `first-sign-in-${sequence}`,
    startedOn: "2026-01-01",
    signedInAt: new Date("2026-01-01T00:00:00Z"),
    timeZone: "Asia/Tokyo",
  }),
});

const syncRequestLogs = defineFactory({
  schema,
  table: "syncRequestLogs",
  resolver: ({ sequence }) => ({
    id: `request-log-${sequence}`,
    deviceId: "device-1",
    receivedAt: new Date("2026-01-01T00:00:00Z"),
    timeZone: "Asia/Tokyo",
    appVersion: "1.0.0",
    osVersion: "26.0",
    pendingWriteCount: 0,
    oldestPendingWriteAgeSeconds: null,
    pendingPhotoCount: 0,
  }),
});

const syncPushLogs = defineFactory({
  schema,
  table: "syncPushLogs",
  resolver: ({ use }) => ({
    // use は、指定されなかったときだけ呼ばれるよう関数で包む
    syncRequestLogId: () =>
      use(syncRequestLogs)
        .create()
        .then((log) => log.id),
    isFinalBatch: true,
  }),
});

const syncWriteReceipts = defineFactory({
  schema,
  table: "syncWriteReceipts",
  resolver: ({ sequence, use }) => ({
    id: `write-${sequence}`,
    syncRequestLogId: () =>
      use(syncPushLogs)
        .create()
        .then((log) => log.syncRequestLogId),
    positionInRequest: 0,
    kind: "create" as const,
    recordType: "weight_record" as const,
    recordId: `record-${sequence}`,
    result: "applied" as const,
  }),
});

const syncWriteRejections = defineFactory({
  schema,
  table: "syncWriteRejections",
  resolver: ({ use }) => ({
    syncWriteReceiptId: () =>
      use(syncWriteReceipts)
        .create({ result: "rejected" })
        .then((receipt) => receipt.id),
    reason: "out_of_range" as const,
  }),
});

const recordChanges = defineFactory({
  schema,
  table: "recordChanges",
  resolver: ({ sequence }) => ({
    sequence,
    recordType: "weight_record" as const,
    recordId: `record-${sequence}`,
  }),
});

const weightRecords = defineFactory({
  schema,
  table: "weightRecords",
  resolver: ({ sequence }) => ({
    id: `weight-record-${sequence}`,
    weightKg: 60.5,
    measuredAt: new Date("2026-01-01T00:00:00Z"),
    timeZone: "Asia/Tokyo",
    version: 1,
  }),
});

const importedWeightRecords = defineFactory({
  schema,
  table: "importedWeightRecords",
  resolver: ({ sequence, use }) => ({
    weightRecordId: () =>
      use(weightRecords)
        .create()
        .then((record) => record.id),
    sourceAppName: "Health",
    sourceBundleId: "com.example.health",
    healthkitSampleUuid: `weight-sample-${sequence}`,
  }),
});

const importedBodyFatPercentages = defineFactory({
  schema,
  table: "importedBodyFatPercentages",
  resolver: ({ sequence, use }) => ({
    weightRecordId: () =>
      use(importedWeightRecords)
        .create()
        .then((record) => record.weightRecordId),
    bodyFatPercentage: 20.5,
    healthkitSampleUuid: `body-fat-sample-${sequence}`,
  }),
});

const weightRecordDeletions = defineFactory({
  schema,
  table: "weightRecordDeletions",
  resolver: ({ use }) => ({
    syncWriteReceiptId: () =>
      use(syncWriteReceipts)
        .create()
        .then((receipt) => receipt.id),
  }),
});

const accountSettings = defineFactory({
  schema,
  table: "accountSettings",
  resolver: ({ sequence }) => ({
    id: `account-settings-${sequence}`,
    sendsUsageData: false,
  }),
});

// 置き場のテストで行を作る。create() は Promise を返すので、テストで await する。transactionSync の中では使わない
export const durableObjectFactory = composeFactory({
  firstSignIns,
  syncRequestLogs,
  syncPushLogs,
  syncWriteReceipts,
  syncWriteRejections,
  recordChanges,
  weightRecords,
  importedWeightRecords,
  importedBodyFatPercentages,
  weightRecordDeletions,
  accountSettings,
});
