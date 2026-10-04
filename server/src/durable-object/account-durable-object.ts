import { R } from "@praha/byethrow";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { captureException, instrumentDurableObjectWithSentry, setUser } from "@sentry/cloudflare";
import { DurableObject } from "cloudflare:workers";
import { sendsUsageData } from "../account-settings/domain/sends-usage-data";
import { recordFirstSignIn } from "../domain/record-first-sign-in";
import { applySyncWrites } from "../domain/apply-sync-writes";
import { computeNextAlarmAt } from "../domain/compute-next-alarm-at";
import { pullSyncChanges } from "../domain/pull-sync-changes";
import { receiveMealPhoto, type MealPhotoReceiptFailedError } from "../domain/receive-meal-photo";
import { runAccountAlarm } from "../domain/run-account-alarm";
import type { SyncClientState } from "../domain/sync-client-state";
import type { SyncWrite } from "../domain/sync-write";
import { createEstimationProvider } from "../estimation/durable-object/create-estimation-provider";
import { readKeptMealPhoto } from "../meal/domain/read-kept-meal-photo";
import { createMealPhotoArchive } from "../meal/durable-object/create-meal-photo-archive";
import { createSentryOptions } from "../observability/create-sentry-options";
import { sendUsageEvents } from "../observability/send-usage-events";
import { applyDurableObjectMigrations } from "./apply-durable-object-migrations";
import { createFirstSignInStore } from "./create-first-sign-in-store";
import { createRecordKindStores } from "./create-record-kind-stores";
import { createLedgerStore } from "./create-ledger-store";
import { durableObjectMigrations } from "./durable-object-migrations";

// 受け口は呼ぶたびに accountId を渡す。Sentry の報告に user の ID として付けるため
export const AccountDurableObject = instrumentDurableObjectWithSentry(
  createSentryOptions,
  class extends DurableObject<Env> {
    constructor(ctx: DurableObjectState, env: Env) {
      super(ctx, env);
      applyDurableObjectMigrations(ctx.storage, durableObjectMigrations);
    }

    recordFirstSignIn(
      accountId: string,
      signIn: { signedInAt: Date; timeZone: string | undefined },
    ): void {
      setUser({ id: accountId });
      recordFirstSignIn(createFirstSignInStore(drizzle(this.ctx.storage)), signIn);
    }

    async pushSyncWrites(
      accountId: string,
      request: { clientState: SyncClientState; writes: SyncWrite[]; isFinalBatch: boolean },
    ) {
      setUser({ id: accountId });
      const { results, usageEvents } = applySyncWrites(
        createLedgerStore(this.ctx.storage),
        createRecordKindStores(this.ctx.storage),
        {
          ...request,
          receivedAt: new Date(),
        },
      );
      await this.armAlarm();
      await sendUsageEvents(this.env, accountId, usageEvents);
      return results;
    }

    async pullSyncChanges(
      accountId: string,
      request: { clientState: SyncClientState; afterSequence: number },
    ) {
      setUser({ id: accountId });
      const { usageEvents, ...pulled } = pullSyncChanges(
        createLedgerStore(this.ctx.storage),
        createRecordKindStores(this.ctx.storage),
        {
          ...request,
          receivedAt: new Date(),
        },
      );
      await sendUsageEvents(this.env, accountId, usageEvents);
      return pulled;
    }

    // 失敗したら PostHog に送り、失敗を受け口に返す。受け口は 500 にし、要求ごとのログに失敗した段を出す
    async receiveMealPhoto(
      accountId: string,
      request: { photoId: string; photo: ArrayBuffer },
    ): R.ResultAsync<void, MealPhotoReceiptFailedError> {
      setUser({ id: accountId });
      const stores = createRecordKindStores(this.ctx.storage);
      return R.pipe(
        receiveMealPhoto(
          createLedgerStore(this.ctx.storage),
          stores,
          createMealPhotoArchive(this.env.PHOTOS, accountId),
          { ...request, receivedAt: new Date() },
        ),
        R.inspect(() => this.armAlarm()),
        R.inspectError(({ stage }) =>
          sendUsageEvents(
            this.env,
            accountId,
            sendsUsageData(stores.accountSettings)
              ? [{ name: "meal_photo_receipt_failed", stage }]
              : [],
          ),
        ),
      );
    }

    async readMealPhoto(accountId: string, photoId: string): Promise<ArrayBuffer | undefined> {
      setUser({ id: accountId });
      return readKeptMealPhoto(
        createRecordKindStores(this.ctx.storage).mealPhoto,
        createMealPhotoArchive(this.env.PHOTOS, accountId),
        photoId,
      );
    }

    async deleteRecords(accountId: string): Promise<void> {
      setUser({ id: accountId });
      await this.ctx.storage.deleteAlarm();
      await this.ctx.storage.deleteAll();
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
      const ran = await runAccountAlarm(
        createLedgerStore(this.ctx.storage),
        createRecordKindStores(this.ctx.storage),
        {
          archive: createMealPhotoArchive(this.env.PHOTOS, accountId),
          provider: createEstimationProvider(this.env, accountId),
          armAlarm: () => this.armAlarm(),
        },
      );
      await this.setAlarm(ran.nextAlarmAt);
      for (const providerError of ran.providerErrors) {
        captureException(providerError);
      }
      await sendUsageEvents(this.env, accountId, ran.usageEvents);
      console.log({
        accountId,
        route: "alarm",
        error: ran.error instanceof Error ? ran.error.name : undefined,
        failedStage:
          ran.error instanceof Error && "stage" in ran.error ? ran.error.stage : undefined,
        estimationAttempts: ran.attempts,
        durationMs: Date.now() - startedAt,
      });
      // Sentry に届け、Cloudflare のアラームのやり直しに任せる
      if (ran.error !== undefined) {
        throw ran.error;
      }
    }

    // 送る要求と写真の要求の入口で、表から出したいちばん早い時刻に張り直す
    private async armAlarm(): Promise<void> {
      await this.setAlarm(computeNextAlarmAt(createRecordKindStores(this.ctx.storage), new Date()));
    }

    private async setAlarm(alarmAt: Date | undefined): Promise<void> {
      if (alarmAt !== undefined) {
        await this.ctx.storage.setAlarm(alarmAt);
      }
    }
  },
);

export type AccountDurableObject = InstanceType<typeof AccountDurableObject>;
