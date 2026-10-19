import { drizzle } from "drizzle-orm/durable-sqlite";
import { captureException, instrumentDurableObjectWithSentry, setUser } from "@sentry/cloudflare";
import { DurableObject } from "cloudflare:workers";
import { accountRequests } from "../account/domain/account-requests";
import type { AccountResponse } from "../account/domain/account-response";
import type { RecordId } from "../domain/record-id";
import type { SyncClientState } from "../domain/sync-client-state";
import type { SyncWrite } from "../domain/sync-write";
import { createEstimationProvider } from "../estimation/durable-object/create-estimation-provider";
import { createMealPhotoArchive } from "../meal/durable-object/create-meal-photo-archive";
import { createReplyWatchers } from "../reply/domain/create-reply-watchers";
import { createConversationProvider } from "../reply/durable-object/create-conversation-provider";
import { createReplyStream } from "../reply/durable-object/create-reply-stream";
import { createSentryOptions } from "../observability/create-sentry-options";
import { sendUsageEvents } from "../observability/send-usage-events";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createRecordChangeWriter } from "./create-record-change-writer";
import { createRecordKindStores } from "./create-record-kind-stores";
import { createLedgerStore } from "./create-ledger-store";
import { durableObjectMigrations } from "./durable-object-migrations";

// 受け口は呼ぶたびに accountId を渡す。Sentry の報告に user の ID として付けるため。
// 要求ごとの処理はアカウントの口（accountRequests）が持ち、ここではストアを組んで渡し、答えのアラームを張り、出来事を送る
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
      signIn: { signedInAt: Date; timeZone: string | undefined },
    ): Promise<void> {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.recordFirstSignIn(
          { firstSignIn: createFirstSignInStore(drizzle(this.ctx.storage)) },
          signIn,
        ),
      );
    }

    pushSyncWrites(
      accountId: string,
      request: { clientState: SyncClientState; writes: SyncWrite[]; isFinalBatch: boolean },
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.pushSyncWrites(this.createSyncStores(), request, new Date()),
      );
    }

    pullSyncChanges(
      accountId: string,
      request: { clientState: SyncClientState; afterSequence: number },
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.pullSyncChanges(this.createSyncStores(), request, new Date()),
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
            records: createRecordKindStores(this.ctx.storage),
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
            records: createRecordKindStores(this.ctx.storage),
            mealPhotoArchive: createMealPhotoArchive(this.env.PHOTOS, accountId),
          },
          photoId,
        ),
      );
    }

    // 送った文章の見守る要求。文章が無ければ undefined
    watchReply(
      accountId: string,
      sentTextId: RecordId,
    ): Promise<ReadableStream<Uint8Array> | undefined> {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.watchReply(
          {
            openReplyStream: (id) =>
              createReplyStream(this.replyWatchers, createRecordKindStores(this.ctx.storage), id),
          },
          sentTextId,
        ),
      );
    }

    // 目標の設定の、その場で答える要求。どの要求も、要求に載った身体データと摂取エネルギーを残さない
    previewGoalSetup(
      accountId: string,
      request: Parameters<typeof accountRequests.previewGoalSetup>[1],
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.previewGoalSetup(this.createRecordStores(), request, new Date()),
      );
    }

    proposeGoals(accountId: string, request: Parameters<typeof accountRequests.proposeGoals>[1]) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.proposeGoals(this.createRecordStores(), request, new Date()),
      );
    }

    assessCustomTargetWeight(
      accountId: string,
      request: Parameters<typeof accountRequests.assessCustomTargetWeight>[1],
    ) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.assessCustomTargetWeight(this.createRecordStores(), request, new Date()),
      );
    }

    // 目標を決める。決めたら、目標・1日の目安・推定消費カロリーの記録を、応答と同期の両方に出す
    decideGoal(accountId: string, request: Parameters<typeof accountRequests.decideGoal>[1]) {
      setUser({ id: accountId });
      return this.respond(
        accountId,
        accountRequests.decideGoal(
          {
            writeRecordChanges: createRecordChangeWriter(this.ctx.storage),
            records: createRecordKindStores(this.ctx.storage),
          },
          request,
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
          records: createRecordKindStores(this.ctx.storage),
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

    private createSyncStores() {
      return {
        ledger: createLedgerStore(this.ctx.storage),
        records: createRecordKindStores(this.ctx.storage),
      };
    }

    private createRecordStores() {
      return { records: createRecordKindStores(this.ctx.storage) };
    }

    // 答えの時刻に張り、出来事を送ってから、結果を返す
    private async respond<Result>(
      accountId: string,
      { result, nextAlarmAt, usageEvents }: AccountResponse<Result>,
    ): Promise<Result> {
      if (nextAlarmAt !== undefined) {
        await this.ctx.storage.setAlarm(nextAlarmAt);
      }
      await sendUsageEvents(this.env, accountId, usageEvents);
      return result;
    }
  },
);

export type AccountDurableObject = InstanceType<typeof AccountDurableObject>;
