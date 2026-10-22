import { drizzle } from "drizzle-orm/durable-sqlite";
import { captureException, instrumentDurableObjectWithSentry, setUser } from "@sentry/cloudflare";
import { DurableObject } from "cloudflare:workers";
import { selectSendableUsageEvents } from "../account-settings/domain/select-sendable-usage-events";
import { createAccountSettingsStore } from "../account-settings/durable-object/create-account-settings-store";
import { accountRequests } from "../account/domain/account-requests";
import type {
  AccountRequestLog,
  AccountResponse,
  LoggedAccountResponse,
} from "../account/domain/account-response";
import type { RecordId } from "../domain/record-id";
import type { SyncClientState } from "../domain/sync-client-state";
import type { SyncWrite } from "../domain/sync-write";
import { createEstimationProvider } from "../estimation/durable-object/create-estimation-provider";
import { createMealPhotoArchive } from "../meal/durable-object/create-meal-photo-archive";
import { createReplyWatchers } from "../reply/domain/create-reply-watchers";
import { createConversationProvider } from "../reply/durable-object/create-conversation-provider";
import { createReplyStream } from "../reply/durable-object/create-reply-stream";
import { createSentryOptions } from "../observability/create-sentry-options";
import { readSubscriptionAccount } from "../subscription/d1/read-subscription-account";
import { createSubscriptionTransactionStore } from "../subscription/durable-object/create-subscription-transaction-store";
import { createTermsAgreementStore } from "../terms-agreement/durable-object/create-terms-agreement-store";
import { sendUsageEvents } from "../observability/send-usage-events";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createRecordChangeWriter } from "./create-record-change-writer";
import { createRecordKindStores } from "./create-record-kind-stores";
import { createLedgerStore } from "./create-ledger-store";
import { durableObjectMigrations } from "./durable-object-migrations";

// 受け口は呼ぶたびに accountId を渡す。Sentry の報告に user の ID として付けるため。
// 要求ごとの処理はアカウントの口（accountRequests）が持ち、ここではストアを組んで渡し、答えのアラームを張り、出来事を利用状況の設定で絞って送る
export const AccountDurableObject = instrumentDurableObjectWithSentry(
  createSentryOptions,
  class extends DurableObject<Env> {
    // 見守る要求と、試みが流している途中の文。実体のメモリにだけ持ち、受け口の要求とアラームが同じものを使う
    private readonly replyWatchers = createReplyWatchers();

    constructor(ctx: DurableObjectState, env: Env) {
      super(ctx, env);
      applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
    }

    recordFirstSignIn(
      accountId: string,
      signIn: Parameters<typeof accountRequests.recordFirstSignIn>[1],
    ): Promise<void> {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.recordFirstSignIn(
          {
            firstSignIn: createFirstSignInStore(drizzle(this.ctx.storage)),
            termsAgreement: createTermsAgreementStore(drizzle(this.ctx.storage)),
            writeRecordChanges: createRecordChangeWriter(this.ctx.storage),
          },
          signIn,
        ),
      );
    }

    async pushSyncWrites(
      accountId: string,
      request: { clientState: SyncClientState; writes: SyncWrite[]; isFinalBatch: boolean },
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.pushSyncWrites(await this.createSyncStores(accountId), request, new Date()),
      );
    }

    async pullSyncChanges(
      accountId: string,
      request: { clientState: SyncClientState; afterSequence: number },
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.pullSyncChanges(
          await this.createSyncStores(accountId),
          request,
          new Date(),
        ),
      );
    }

    // 失敗は受け口に返す。受け口は 500 にし、要求ごとのログに失敗した段を出す
    async receiveMealPhoto(accountId: string, request: { photoId: RecordId; photo: ArrayBuffer }) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        await accountRequests.receiveMealPhoto(
          {
            writeRecordChanges: createRecordChangeWriter(this.ctx.storage),
            records: await this.createRecordKindStores(accountId),
            mealPhotoArchive: createMealPhotoArchive(this.env.PHOTOS, accountId),
          },
          request,
          new Date(),
        ),
      );
    }

    async readMealPhoto(accountId: string, photoId: RecordId): Promise<ArrayBuffer | undefined> {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        await accountRequests.readMealPhoto(
          {
            records: await this.createRecordKindStores(accountId),
            mealPhotoArchive: createMealPhotoArchive(this.env.PHOTOS, accountId),
          },
          photoId,
        ),
      );
    }

    // 送った文章の見守る要求。文章が無ければ undefined
    async watchReply(
      accountId: string,
      sentTextId: RecordId,
    ): Promise<ReadableStream<Uint8Array> | undefined> {
      setUser({ id: accountId });
      const records = await this.createRecordKindStores(accountId);
      return this.respond(
        accountId,
        accountRequests.watchReply(
          {
            openReplyStream: (id) => createReplyStream(this.replyWatchers, records, id),
          },
          sentTextId,
        ),
      );
    }

    // 目標の設定の、その場で答える要求。どの要求も、要求に載った身体データと摂取エネルギーを残さない。
    // 時刻は受け口が渡す（確かめのジョブが、開発用の環境で過去の時刻に差し替えるため。resolve-requested-at.ts）
    async previewGoalSetup(
      accountId: string,
      request: Parameters<typeof accountRequests.previewGoalSetup>[1],
      now: Date,
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.previewGoalSetup(await this.createRecordStores(accountId), request, now),
      );
    }

    async proposeGoals(
      accountId: string,
      request: Parameters<typeof accountRequests.proposeGoals>[1],
      now: Date,
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.proposeGoals(await this.createRecordStores(accountId), request, now),
      );
    }

    async assessCustomTargetWeight(
      accountId: string,
      request: Parameters<typeof accountRequests.assessCustomTargetWeight>[1],
      now: Date,
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.assessCustomTargetWeight(
          await this.createRecordStores(accountId),
          request,
          now,
        ),
      );
    }

    // 目標を決める。決めたら、目標・1日の目安・推定消費カロリーの記録を、応答と同期の両方に出す
    async decideGoal(
      accountId: string,
      request: Parameters<typeof accountRequests.decideGoal>[1],
      now: Date,
    ) {
      setUser({ id: accountId });
      return this.respondWithRequestLog(
        accountId,
        accountRequests.decideGoal(await this.createRecordStores(accountId), request, now),
      );
    }

    findTermsAgreementRequirement(accountId: string) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.findTermsAgreementRequirement({
          termsAgreement: createTermsAgreementStore(drizzle(this.ctx.storage)),
        }),
      );
    }

    agreeToTerms(accountId: string, request: Parameters<typeof accountRequests.agreeToTerms>[1]) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.agreeToTerms(
          { termsAgreement: createTermsAgreementStore(drizzle(this.ctx.storage)) },
          request,
          new Date(),
        ),
      );
    }

    // 端末からの取引の知らせ。案内は受け口が D1 で決めてから呼ぶ
    async reportSubscriptionTransaction(
      accountId: string,
      report: Parameters<typeof accountRequests.reportSubscriptionTransaction>[1],
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.reportSubscriptionTransaction(
          {
            ...(await this.createRecordStores(accountId)),
            subscriptionTransaction: createSubscriptionTransactionStore(drizzle(this.ctx.storage)),
          },
          report,
          new Date(),
        ),
      );
    }

    // App Store のサーバー通知。案内は受け口が D1 で決めてから呼ぶ
    async receiveAppStoreServerNotification(
      accountId: string,
      notification: Parameters<typeof accountRequests.receiveAppStoreServerNotification>[1],
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.receiveAppStoreServerNotification(
          {
            ...(await this.createRecordStores(accountId)),
            subscriptionTransaction: createSubscriptionTransactionStore(drizzle(this.ctx.storage)),
          },
          notification,
          new Date(),
        ),
      );
    }

    async deleteRecords(accountId: string): Promise<void> {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        await accountRequests.deleteRecords({
          eraseRecords: async () => {
            await this.ctx.storage.deleteAlarm();
            await this.ctx.storage.deleteAll();
          },
        }),
      );
    }

    // アラームには受け口が無いので、アカウント ID は idFromName で付けた名前から得る。
    // 受け口の要求ごとのログと同じ形で、呼び出しごとにログを出す
    override async alarm(): Promise<void> {
      const accountId = this.ctx.id.name;
      if (accountId === undefined) {
        throw new Error("アラームの中でアカウント ID が読めない");
      }
      setUser({ id: accountId });
      const startedAt = Date.now();
      const ran = await this.respond(
        accountId,
        await accountRequests.runAlarm({
          writeRecordChanges: createRecordChangeWriter(this.ctx.storage),
          records: await this.createRecordKindStores(accountId),
          mealPhotoArchive: createMealPhotoArchive(this.env.PHOTOS, accountId),
          estimationProvider: createEstimationProvider(this.env, accountId),
          conversationProvider: createConversationProvider(this.env, accountId),
          replyWatchers: this.replyWatchers,
          armAlarmAt: (alarmAt) => this.ctx.storage.setAlarm(alarmAt),
        }),
      );
      for (const providerError of ran.providerErrors) {
        captureException(providerError);
      }
      console.log({
        accountId,
        route: "alarm",
        error: ran.error instanceof Error ? ran.error.name : undefined,
        failedStage:
          ran.error instanceof Error && "stage" in ran.error ? ran.error.stage : undefined,
        classifications: ran.classifications,
        estimationAttempts: ran.attempts,
        replyAttempts: ran.replyAttempts,
        durationMs: Date.now() - startedAt,
      });
      // Sentry に届け、Cloudflare のアラームのやり直しに任せる
      if (ran.error !== undefined) {
        throw ran.error;
      }
    }

    private async createSyncStores(accountId: string) {
      return {
        ledger: createLedgerStore(this.ctx.storage),
        ...(await this.createRecordStores(accountId)),
      };
    }

    private async createRecordStores(accountId: string) {
      return {
        writeRecordChanges: createRecordChangeWriter(this.ctx.storage),
        records: await this.createRecordKindStores(accountId),
      };
    }

    // サブスクリプションの状態の元のうち、Durable Object の外にあるもの（D1 と環境変数）を読んでから組む
    private async createRecordKindStores(accountId: string) {
      return createRecordKindStores(
        this.ctx.storage,
        await readSubscriptionAccount(this.env, accountId),
      );
    }

    // 要求ごとのログに足す値も、結果と一緒に受け口へ返す
    private async respondWithRequestLog<Result>(
      accountId: string,
      response: LoggedAccountResponse<Result>,
    ): Promise<{ result: Result; requestLog: AccountRequestLog }> {
      return { result: await this.respond(accountId, response), requestLog: response.requestLog };
    }

    // 答えの時刻に張り、出来事を送ってから、結果を返す。
    // 出来事はどの入口のものもここを通ってアカウントから出るので、送るかどうか（利用状況の設定）はここで1度だけ決める。
    // 設定は、口が答えを出し終えた直後（同じ要求で切り替えた書き込みを当てたあと）に、何も待たずに読む
    private async respond<Result>(
      accountId: string,
      { result, nextAlarmAt, usageEvents }: AccountResponse<Result>,
    ): Promise<Result> {
      const sendableUsageEvents = selectSendableUsageEvents(
        createAccountSettingsStore(drizzle(this.ctx.storage)),
        usageEvents,
      );
      if (nextAlarmAt !== undefined) {
        await this.ctx.storage.setAlarm(nextAlarmAt);
      }
      await sendUsageEvents(this.env, accountId, sendableUsageEvents);
      return result;
    }
  },
);

export type AccountDurableObject = InstanceType<typeof AccountDurableObject>;
