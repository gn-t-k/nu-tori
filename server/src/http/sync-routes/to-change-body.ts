import { match } from "ts-pattern";
import type { RecordType } from "../../domain/record-type";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { HttpRecordKind } from "./http-record-kind";
import { httpRecordKinds } from "./http-record-kinds";

// 取りに行く変更と、受け付けなかった書き込みに添える今の値の、通し番号を除いた形。種類によらず、削除の印は <種類>_deletion、
// 記録が無くなったこと（体重の傾向だけが届ける）は <種類>_absence で、どちらも record は空
export const toChangeBody = (
  recordType: RecordType,
  recordId: string,
  current: CurrentRecord<unknown>,
) => {
  const kind: HttpRecordKind = httpRecordKinds[recordType];
  return match(current)
    .with({ status: "absent" }, () => ({ kind: `${recordType}_absence`, recordId, record: {} }))
    .with({ status: "deleted" }, () => {
      if (!kind.keepsDeletionMarks) {
        throw new Error(`削除の印を持たない種類の削除の印: ${recordType} ${recordId}`);
      }
      return { kind: `${recordType}_deletion`, recordId, record: {} };
    })
    .with({ status: "value" }, ({ value }) => ({
      kind: recordType,
      recordId,
      record: kind.toRecord(value, recordId),
    }))
    .exhaustive();
};
