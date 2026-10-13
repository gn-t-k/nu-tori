import { R } from "@praha/byethrow";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import { computeUtcOffsetSeconds } from "../../domain/compute-utc-offset-seconds";
import { generateRecordId } from "../../domain/record-id";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import type { TokenUsage } from "../../domain/token-usage";
import { scheduleMealEstimation } from "../../estimation/domain/schedule-meal-estimation";
import type { Meal } from "../../meal/domain/meal";
import type {
  ClassificationLabel,
  ConversationProvider,
} from "../../reply/domain/conversation-provider";
import type { LlmCallError } from "../../domain/llm-call-error";
import { createReplyRequest } from "../../reply/domain/create-reply-request";
import type { SentText } from "./sent-text";
import type { SentTextClassification } from "./sent-text-classification";

// アラームの読み分けの入口。読み分けを待っている文章を、送った順に1つずつ提供元に読ませ、1つのトランザクションで結果を書く。
// 食事なら文章の食事を1つ作って推定の予定に入れ、会話・決めかねる・呼び出しの失敗なら会話にして返事の依頼を作る（#419 の「読み分け」）。
// 読み分けは推定の回数にも返事の回数にも数えない。呼んでいるあいだに止まったら、行が無いまま残り、次のアラームで読み直す
export const classifySentTexts = async (
  writeRecordChanges: RecordChangeWriter,
  stores: ClassificationStores & Pick<RecordKindStores, "accountSettings">,
  deps: { provider: ConversationProvider },
): Promise<{
  // 利用状況を送らない人には空
  usageEvents: UsageEvent[];
  // アラームの呼び出しごとのログに出す、呼び出しごとの結果
  classifications: ClassificationReport[];
  // Sentry に包まずに送る、呼び出しの失敗（応答のエラーがあればその内容、無ければ失敗そのもの）。
  // 本番のクレジットが尽きるとすべての文章が会話になるので、急増で気づく（#419 の「観測」）
  providerErrors: unknown[];
}> => {
  const usageEvents: UsageEvent[] = [];
  const classifications: ClassificationReport[] = [];
  const providerErrors: unknown[] = [];
  for (const { sentText, receivedAt } of stores.sentText.findUnclassified()) {
    // 送った順に書くため、1つずつ呼ぶ
    const { providerResult, usage, providerError } = await askClassification(
      deps.provider,
      sentText,
    );
    const result = providerResult === "meal" ? "meal" : "conversation";
    const classifiedAt = new Date();
    if (recordClassification(writeRecordChanges, stores, sentText, result, classifiedAt)) {
      const providerErrorType = providerError?.errorType;
      if (providerError !== undefined) {
        providerErrors.push(providerError.cause ?? providerError);
      }
      classifications.push({ result, providerResult, providerErrorType });
      usageEvents.push({
        name: "sent_text_classified",
        result,
        providerResult,
        usage,
        secondsFromReceivedToClassified: Math.round(
          (classifiedAt.getTime() - receivedAt.getTime()) / 1000,
        ),
        providerErrorType,
      });
    }
  }
  return {
    usageEvents: sendsUsageData(stores.accountSettings) ? usageEvents : [],
    classifications,
    providerErrors,
  };
};

type ClassificationStores = Pick<
  RecordKindStores,
  "estimationSchedule" | "latestTimeZone" | "meal" | "mealPhoto" | "sentText" | "sentTextStatus"
>;

type ClassificationReport = {
  result: SentTextClassification;
  providerResult: ProviderClassification["providerResult"];
  providerErrorType: string | undefined;
};

// 提供元の答え。呼び出しが失敗したら failed にし、失敗を持つ
type ProviderClassification =
  | { providerResult: ClassificationLabel; usage: TokenUsage; providerError: undefined }
  | { providerResult: "failed"; usage: undefined; providerError: LlmCallError };

// 呼び出しの失敗も会話にするので、ここで提供元の Result を答えに直す
const askClassification = async (
  provider: ConversationProvider,
  sentText: SentText,
): Promise<ProviderClassification> => {
  const classified = await provider.classifySentText({ body: sentText.body });
  return R.isSuccess(classified)
    ? {
        providerResult: classified.value.label,
        usage: classified.value.usage,
        providerError: undefined,
      }
    : { providerResult: "failed", usage: undefined, providerError: classified.error };
};

// 読み分けの結果と、文章の食事か返事の依頼を書く。呼んでいるあいだにほかで読み分けていたら、何も書かずに false を返す
const recordClassification = (
  writeRecordChanges: RecordChangeWriter,
  stores: ClassificationStores,
  sentText: SentText,
  result: SentTextClassification,
  classifiedAt: Date,
): boolean =>
  writeRecordChanges(({ addChange, estimationAt, reply }) => {
    if (stores.sentTextStatus.findClassification(sentText.id) !== undefined) {
      return false;
    }
    stores.sentText.insertClassification({ sentTextId: sentText.id, classifiedAt, result });
    addChange({ recordType: "sent_text_status", recordId: sentText.id });
    if (result === "conversation") {
      // 応答待ちになった状態の変更は、入口が足す（取りに行く応答では、同じ文章の変更は1つにまとまる）
      reply.request(
        createReplyRequest(sentText, classifiedAt, stores.latestTimeZone, {
          type: "classification",
        }),
      );
      return true;
    }
    // 時刻は送った時刻。推定が決めた時刻は、推定が終わったときに別に書く（#426）
    const meal: Meal = {
      id: generateRecordId(),
      eatenAt: sentText.sentAt,
      eatenAtUtcOffsetSeconds: computeUtcOffsetSeconds(sentText.sentAt, sentText.timeZone),
      sentAt: sentText.sentAt,
      sentTimeZone: sentText.timeZone,
      entryMethod: "written",
      photoIds: [],
      sentTextId: sentText.id,
    };
    stores.meal.insert(meal);
    addChange({ recordType: "meal", recordId: meal.id });
    // 推定の状態の変更（推定中）は、入口が足す
    scheduleMealEstimation(stores, estimationAt(classifiedAt), meal, classifiedAt);
    return true;
  });
