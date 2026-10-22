import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { FirstSignInStore } from "../../domain/record-first-sign-in";
import type { RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { EstimationProvider } from "../../estimation/domain/estimation-provider";
import type { MealPhotoArchive } from "../../meal/domain/meal-photo-archive";
import type { ConversationProvider } from "../../reply/domain/conversation-provider";
import type { ReplyWatchers } from "../../reply/domain/create-reply-watchers";
import type { SubscriptionTransactionStore } from "../../subscription/domain/subscription-transaction-store";
import type { TermsAgreementStore } from "../../terms-agreement/domain/terms-agreement-store";

// アカウントの口が使う置き場と外への呼び出し。基盤に固有の層（Durable Object）が実装し、要求ごとに要るものだけを渡す
export type AccountStores = {
  ledger: LedgerStore<RecordType>;
  records: RecordKindStores;
  writeRecordChanges: RecordChangeWriter;
  firstSignIn: FirstSignInStore;
  termsAgreement: TermsAgreementStore;
  subscriptionTransaction: SubscriptionTransactionStore;
  mealPhotoArchive: MealPhotoArchive;
  estimationProvider: EstimationProvider;
  conversationProvider: ConversationProvider;
  replyWatchers: ReplyWatchers;
  // 見守る要求の流れを開く。送った文章が無ければ undefined
  openReplyStream: (sentTextId: RecordId) => ReadableStream<Uint8Array> | undefined;
  // アラームの途中で張り直す。推定と返事は、試みを書いたあと、提供元を呼ぶ前に張る
  armAlarmAt: (alarmAt: Date) => Promise<void>;
  // アラームを外し、記録をすべて消す
  eraseRecords: () => Promise<void>;
};
