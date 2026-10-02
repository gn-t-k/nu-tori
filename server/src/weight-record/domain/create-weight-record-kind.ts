import { match } from "ts-pattern";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind, WriteDecision } from "../../domain/sync-ledger/record-kind";
import type { WriteKind } from "../../domain/sync-ledger/write-kind";
import type { SyncWriteOutcome } from "../../domain/sync-write-outcome";
import { isWithinAcceptedRange } from "../../domain/is-within-accepted-range";
import { relearnUsualWeighingTime } from "../../usual-weighing-time/domain/relearn-usual-weighing-time";
import type { UsualWeighingTimeStore } from "../../usual-weighing-time/domain/usual-weighing-time-store";
import { weightTrendRecordId } from "../../weight-trend/domain/weight-trend-record-id";
import type { WeightRecord } from "./weight-record";
import type { WeightRecordStore } from "./weight-record-store";
import { type WeightRecordWrite, weightRecordWriteTypes } from "./weight-record-write";

// 使い始めた日より前の日付の記録は、直す書き込みを受け付けない。
// 当てた書き込みのたびに、体重の傾向の変更を載せ、いつもの時刻を学び直す
export const createWeightRecordKind = (
  dependencies: Dependencies,
): RecordKind<"weight_record", WeightRecordWrite, WeightRecord, AddedRecordType> => ({
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
  deliversAbsence: false,
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
  usualWeighingTimeStore: UsualWeighingTimeStore;
  findStartedOn: () => string | undefined;
  // ユーザーの最新のタイムゾーン。いつもの時刻の基準の今日を決める。読めなければ undefined
  findLatestTimeZone: () => string | undefined;
  // 要求を受け取った時刻
  receivedAt: Date;
};

// 体重記録の書き込みを当てると、体重の傾向と、いつもの時刻が変わる
type AddedRecordType = "usual_weighing_time" | "weight_trend";

// いつもの時刻の学び直しの材料。時刻と、そのときのタイムゾーンだけを使う
type MeasuredWeightRecord = Pick<WeightRecord, "id" | "measuredAt" | "timeZone">;

const decideCreate = (
  dependencies: Dependencies,
  weightRecord: Omit<WeightRecord, "version">,
): WriteDecision<AddedRecordType> => {
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
  const { store } = dependencies;
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
  return applied(
    dependencies,
    "create",
    weightRecord.id,
    (records) => [...records, weightRecord],
    () => {
      store.insert({ ...weightRecord, version: 1 });
    },
  );
};

const decideUpdate = (
  dependencies: Dependencies,
  weightRecord: Omit<WeightRecord, "imported">,
): WriteDecision<AddedRecordType> => {
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
  const { store } = dependencies;
  if (store.hasDeletion(weightRecord.id)) {
    return settled("update", weightRecord.id, { result: "ignored_tombstone" });
  }
  const current = store.find(weightRecord.id);
  if (current === undefined) {
    return settled("update", weightRecord.id, { result: "rejected", reason: "record_not_found" });
  }
  const startedOn = dependencies.findStartedOn();
  if (
    startedOn !== undefined &&
    computeCalendarDayInTimeZone(current.measuredAt, current.timeZone) < startedOn
  ) {
    return settled("update", weightRecord.id, {
      result: "rejected",
      reason: "record_before_started_on",
    });
  }
  return applied(
    dependencies,
    "update",
    weightRecord.id,
    // 直す前の時刻が読んだ範囲の外でも、直したあとの時刻で入れる
    (records) => [
      ...records.filter((record) => record.id !== weightRecord.id),
      { id: weightRecord.id, measuredAt: weightRecord.measuredAt, timeZone: weightRecord.timeZone },
    ],
    () => {
      // 2台で同じ記録を直したとき、あとに受け取ったほうの版が前より小さくならないようにする
      store.update(weightRecord.id, {
        weightKg: weightRecord.weightKg,
        measuredAt: weightRecord.measuredAt,
        timeZone: weightRecord.timeZone,
        version: Math.max(weightRecord.version, current.version + 1),
      });
    },
  );
};

const decideSourceDeleted = (
  dependencies: Dependencies,
  weightRecordId: string,
): WriteDecision<AddedRecordType> => {
  const { store } = dependencies;
  if (store.hasDeletion(weightRecordId)) {
    return settled("source_deleted", weightRecordId, { result: "ignored_tombstone" });
  }
  const current = store.find(weightRecordId);
  if (current !== undefined && current.version >= 2) {
    return settled("source_deleted", weightRecordId, { result: "kept_corrected" });
  }
  // 記録がまだ届いていなくても印を残し、あとから届く作る書き込みで生き返らせない
  return applied(
    dependencies,
    "source_deleted",
    weightRecordId,
    (records) => records.filter((record) => record.id !== weightRecordId),
    (receiptId) => {
      if (current !== undefined) {
        store.remove(weightRecordId);
      }
      store.insertDeletion(receiptId);
    },
  );
};

// 行を書かずに終わる。削除の印で捨てたときだけ、変更の並びに載せる
const settled = (
  writeKind: WriteKind,
  recordId: string,
  outcome: Exclude<SyncWriteOutcome, { result: "applied" }>,
): WriteDecision<AddedRecordType> => ({
  writeKind,
  recordId,
  outcome,
  changedRecordId: outcome.result === "ignored_tombstone" ? recordId : undefined,
  addedChanges: [],
  usageEvents: [],
  commit: () => undefined,
});

// apply は、書き込みを当てたあとの体重記録をメモリの上で出す。いつもの時刻は、その体重記録で学び直す
const applied = (
  dependencies: Dependencies,
  writeKind: WriteKind,
  recordId: string,
  apply: (records: readonly MeasuredWeightRecord[]) => readonly MeasuredWeightRecord[],
  commit: WriteDecision<AddedRecordType>["commit"],
): WriteDecision<AddedRecordType> => {
  const relearned = relearnUsualWeighingTime(dependencies.usualWeighingTimeStore, {
    findWeightRecordsMeasuredBetween: dependencies.store.findMeasuredBetween,
    applyWrite: apply,
    now: dependencies.receivedAt,
    latestTimeZone: dependencies.findLatestTimeZone(),
  });
  return {
    writeKind,
    recordId,
    outcome: { result: "applied" },
    changedRecordId: recordId,
    addedChanges: [
      // 傾向は取りに行くときに体重記録から計算するので、変わったことだけを並びに載せる
      { recordType: "weight_trend", recordId: weightTrendRecordId },
      ...(relearned === undefined ? [] : [relearned.change]),
    ],
    usageEvents: [],
    commit: (receiptId) => {
      commit(receiptId);
      relearned?.commit(receiptId);
    },
  };
};
