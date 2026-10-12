import type { EstimationProvider } from "../estimation/domain/estimation-provider";
import type { MealPhotoArchive } from "../meal/domain/meal-photo-archive";
import type { ConversationProvider } from "../reply/domain/conversation-provider";
import type { ReplyWatchers } from "../reply/domain/create-reply-watchers";
import { accountAlarmJobs } from "./account-alarm-jobs";
import type { RecordChangeWriter } from "./record-change-writer";
import type { RecordKindStores } from "./record-kind-stores";
import { runAlarmJobs } from "./run-alarm-jobs";

// 呼び出し側は、次の時刻に張り、提供元のエラーを Sentry に送り、利用状況を送り、error があれば投げて Cloudflare のアラームのやり直しに任せる
export const runAccountAlarm = async (
  writeRecordChanges: RecordChangeWriter,
  stores: RecordKindStores,
  deps: {
    archive: MealPhotoArchive;
    provider: EstimationProvider;
    conversationProvider: ConversationProvider;
    armAlarm: () => Promise<void>;
    replyWatchers: ReplyWatchers;
  },
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
