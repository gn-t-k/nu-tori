import { accountAlarmJobs } from "./account-alarm-jobs";
import type { RecordChangeWriter } from "./record-change-writer";
import type { RecordKindStores } from "./record-kind-stores";
import { runAlarmJobs } from "./run-alarm-jobs";

// 呼び出し側は、次の時刻に張り、提供元のエラーを Sentry に送り、利用状況を送り、error があれば投げて Cloudflare のアラームのやり直しに任せる
export const runAccountAlarm = async (
  writeRecordChanges: RecordChangeWriter,
  stores: RecordKindStores,
  // 仕事の並びが要るもののうち、入口のほか
  deps: Omit<Parameters<(typeof accountAlarmJobs)[number]["advance"]>[1], "writeRecordChanges">,
) => {
  const { nextAlarmAt, error, reports } = await runAlarmJobs(accountAlarmJobs, stores, {
    writeRecordChanges,
    ...deps,
  });
  return {
    nextAlarmAt,
    error,
    providerErrors: reports.flatMap(({ providerErrors }) => providerErrors),
    usageEvents: reports.flatMap(({ usageEvents }) => usageEvents),
    classifications: reports.flatMap(({ classifications }) => classifications),
    attempts: reports.flatMap(({ attempts }) => attempts),
    replyAttempts: reports.flatMap(({ replyAttempts }) => replyAttempts),
  };
};
