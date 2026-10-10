import { composeFactory, defineFactory } from "@praha/drizzle-factory";
import { generateRecordId } from "../../domain/record-id";
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
    recordId: generateRecordId(),
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
    recordId: generateRecordId(),
  }),
});

const weightRecords = defineFactory({
  schema,
  table: "weightRecords",
  resolver: () => ({
    id: generateRecordId(),
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
  resolver: () => ({
    id: generateRecordId(),
    sendsUsageData: false,
  }),
});

const meals = defineFactory({
  schema,
  table: "meals",
  resolver: () => ({
    id: generateRecordId(),
    eatenAt: new Date("2026-01-01T00:00:00Z"),
    eatenAtUtcOffsetSeconds: 32_400,
    sentAt: new Date("2026-01-01T00:00:00Z"),
    sentTimeZone: "Asia/Tokyo",
    entryMethod: "captured" as const,
  }),
});

const sentTexts = defineFactory({
  schema,
  table: "sentTexts",
  resolver: () => ({
    id: generateRecordId(),
    body: "朝はパン",
    sentAt: new Date("2026-01-01T00:00:00Z"),
    sentTimeZone: "Asia/Tokyo",
  }),
});

// 文章の食事。食事を指定しなければ、入口が文章の食事を作る
const sentTextMeals = defineFactory({
  schema,
  table: "sentTextMeals",
  resolver: ({ use }) => ({
    mealId: () =>
      use(meals)
        .create({ entryMethod: "written" })
        .then((meal) => meal.id),
    sentTextId: () =>
      use(sentTexts)
        .create()
        .then((sentText) => sentText.id),
  }),
});

const estimationSchedules = defineFactory({
  schema,
  table: "estimationSchedules",
  resolver: ({ sequence }) => ({
    id: `estimation-schedule-${sequence}`,
    dueAt: new Date("2026-01-01T00:00:00Z"),
    countedOn: "2026-01-01",
  }),
});

const mealEstimationSchedules = defineFactory({
  schema,
  table: "mealEstimationSchedules",
  resolver: ({ use }) => ({
    estimationScheduleId: () =>
      use(estimationSchedules)
        .create()
        .then((schedule) => schedule.id),
    mealId: () =>
      use(meals)
        .create()
        .then((meal) => meal.id),
  }),
});

const estimationDeferrals = defineFactory({
  schema,
  table: "estimationDeferrals",
  resolver: ({ use }) => ({
    estimationScheduleId: () =>
      use(estimationSchedules)
        .create()
        .then((schedule) => schedule.id),
    deferredAt: new Date("2026-01-01T00:00:00Z"),
  }),
});

const estimations = defineFactory({
  schema,
  table: "estimations",
  resolver: ({ sequence, use }) => ({
    id: `estimation-${sequence}`,
    estimationScheduleId: () =>
      use(estimationSchedules)
        .create()
        .then((schedule) => schedule.id),
    startedAt: new Date("2026-01-01T00:00:00Z"),
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
  meals,
  sentTexts,
  sentTextMeals,
  estimationSchedules,
  mealEstimationSchedules,
  estimationDeferrals,
  estimations,
});
