import { match } from "ts-pattern";
import type { RecordId } from "../../domain/record-id";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { readStoredRecord } from "../../domain/sync-ledger/read-stored-record";
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
  readCurrent: (recordId) => readStoredRecord(dependencies.store, recordId),
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
      store.insert({ ...weightRecord, imported: clipSource(weightRecord.imported) });
    },
  };
};

// 出どころの名前とバンドル ID の、保存する長さの上限（コードポイント）。バンドル ID は Apple の決まりで 155 字まで
const maximumSourceTextLength = 255;

// 取り込んだ体重記録の出どころは、上限までに切って保存する。断ると、端末が同じサンプルを取り込み直して送り続ける
const clipSource = (imported: WeightRecord["imported"]): WeightRecord["imported"] =>
  imported === undefined
    ? undefined
    : {
        ...imported,
        sourceAppName: clipText(imported.sourceAppName),
        sourceBundleId: clipText(imported.sourceBundleId),
      };

// 対になっていないサロゲートは、保存すると別の字に置き換わって数が変わるので、先に置き換えてから切る
const clipText = (text: string): string =>
  Array.from(text.toWellFormed()).slice(0, maximumSourceTextLength).join("");

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
  const weightChanged = weightRecord.weightKg !== current.weightKg;
  const measuredAtChanged =
    weightRecord.measuredAt.getTime() !== current.measuredAt.getTime() ||
    weightRecord.timeZone !== current.timeZone;
  // 何も書かなくても控えは当てた扱いになり、版の数に入る。端末が直すたびに版を1つ上げるのとそろう
  if (!weightChanged && !measuredAtChanged) {
    return { result: "unchanged", writeKind: "update", recordId: weightRecord.id };
  }
  // 修正の行の順は変更の並びの通し番号で決まるので、修正を書くときは必ず applied で返し、記録の変更を並びに載せる
  return {
    result: "applied",
    writeKind: "update",
    recordId: weightRecord.id,
    addedChanges: [],
    usageEvents: [],
    commit: (receiptId) => {
      if (weightChanged) {
        store.insertWeightCorrection(receiptId, weightRecord.weightKg);
      }
      if (measuredAtChanged) {
        store.insertMeasuredAtCorrection(receiptId, {
          measuredAt: weightRecord.measuredAt,
          timeZone: weightRecord.timeZone,
        });
      }
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
  // 守りたいのは直した値なので、同じ値で保存しただけの記録は残さない
  if (store.hasCorrection(weightRecordId)) {
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
      // 記録がまだ届いていなければ、消す行は無く何も起きない
      store.remove(weightRecordId);
      store.insertDeletion(receiptId);
    },
  };
};
