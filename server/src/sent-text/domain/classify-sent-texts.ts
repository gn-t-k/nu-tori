import { R } from "@praha/byethrow";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { computeUtcOffsetSeconds } from "../../domain/compute-utc-offset-seconds";
import { createRecordLedger } from "../../domain/create-record-ledger";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import { generateRecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import { scheduleMealEstimation } from "../../estimation/domain/schedule-meal-estimation";
import type { Meal } from "../../meal/domain/meal";
import type { ConversationProvider } from "../../reply/domain/conversation-provider";
import type { SentText } from "./sent-text";

// アラームの読み分けの入口。読み分けを待っている文章を、送った順に1つずつ提供元に読ませ、1つのトランザクションで結果を書く。
// 食事なら文章の食事を1つ作って推定の予定に入れ、会話・決めかねる・呼び出しの失敗なら会話にして返事の依頼を作る（#419 の「読み分け」）。
// 読み分けは推定の回数にも返事の回数にも数えない。呼んでいるあいだに止まったら、行が無いまま残り、次のアラームで読み直す
export const classifySentTexts = async (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
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
    const replied = await deps.provider.classifySentText({ body: sentText.body });
    const providerResult = R.isSuccess(replied) ? replied.value.label : "failed";
    const result = providerResult === "meal" ? "meal" : "conversation";
    const classifiedAt = new Date();
    if (!recordClassification(ledgerStore, stores, sentText, result, classifiedAt)) {
      continue;
    }
    const providerErrorType = R.isFailure(replied) ? replied.error.errorType : undefined;
    if (R.isFailure(replied)) {
      providerErrors.push(replied.error.cause ?? replied.error);
    }
    classifications.push({ result, providerResult, providerErrorType });
    usageEvents.push({
      name: "sent_text_classified",
      result,
      providerResult,
      usage: R.isSuccess(replied) ? replied.value.usage : undefined,
      secondsFromReceivedToClassified: Math.round(
        (classifiedAt.getTime() - receivedAt.getTime()) / 1000,
      ),
      providerErrorType,
    });
  }
  return {
    usageEvents: sendsUsageData(stores.accountSettings) ? usageEvents : [],
    classifications,
    providerErrors,
  };
};

type ClassificationReport = {
  result: "meal" | "conversation";
  providerResult: "meal" | "conversation" | "unsure" | "failed";
  providerErrorType: string | undefined;
};

// 読み分けの結果と、文章の食事か返事の依頼を書く。呼んでいるあいだにほかで読み分けていたら、何も書かずに false を返す
const recordClassification = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  sentText: SentText,
  result: "meal" | "conversation",
  classifiedAt: Date,
): boolean =>
  createRecordLedger(ledgerStore, stores, classifiedAt).changeOutsideWrites((addChange) => {
    if (stores.sentTextStatus.findClassification(sentText.id) !== undefined) {
      return false;
    }
    stores.sentText.insertClassification({ sentTextId: sentText.id, classifiedAt, result });
    addChange({ recordType: "sent_text_status", recordId: sentText.id });
    if (result === "conversation") {
      // 応答待ちになった状態の変更は、返事の書き込みの口が足す（取りに行く応答では、同じ文章の変更は1つにまとまる）
      stores.writeReplyEvents(addChange, (writes) => {
        writes.request({
          id: generateRecordId(),
          sentTextId: sentText.id,
          countedOn: computeCalendarDayInTimeZone(
            classifiedAt,
            findLatestValidTimeZone(stores.latestTimeZone) ?? sentText.timeZone,
          ),
          trigger: { type: "classification" },
        });
      });
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
    // 推定の状態の変更（推定中）は、推定の書き込みの口が足す
    stores.writeEstimationEvents(addChange, classifiedAt, (writes) =>
      scheduleMealEstimation(stores, writes, meal, classifiedAt),
    );
    return true;
  });
