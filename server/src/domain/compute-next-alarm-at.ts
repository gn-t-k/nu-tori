import { accountAlarmJobs } from "./account-alarm-jobs";
import { computeEarliestAlarmAt } from "./compute-earliest-alarm-at";
import type { RecordKindStores } from "./record-kind-stores";

// 要求のあとと、返事を流しているあいだに張る時刻。アラームで動かす仕事の並びから出すので、アラームが張り直す時刻と揃う
export const computeNextAlarmAt = (stores: RecordKindStores, now: Date): Date | undefined =>
  computeEarliestAlarmAt(accountAlarmJobs, stores, now);
