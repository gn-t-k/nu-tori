import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockAccountRequestsOk } from "../account/domain/account-requests.mock";
import { generateRecordId } from "../domain/record-id";
import { useFakeClock } from "../estimation/http/testing/use-fake-clock";
import type { SyncClientState } from "../domain/sync-client-state";
import { enableUsageEventSending } from "../http/sync-routes/testing/enable-usage-event-sending";
import { mockSetUserOk } from "../observability/set-user.mock";
import { mockPostHogCaptureEndpointOk, readPostHogCapturedEvents } from "../observability/testing";
import { durableObjectTables } from "./durable-object-tables";
import { getAccountDurableObject } from "./get-account-durable-object";
import { durableObjectFactory } from "./testing/durable-object-factory";

describe("アカウントの Durable Object", () => {
  describe("使い始めた日を決める呼び出しに、受け口がアカウント ID を渡したとき", () => {
    let accountId: string;
    let signIn: {
      signedInAt: Date;
      timeZone: string | undefined;
      isFreeTrialUsedByEarlierAccount: boolean;
      agreedTermsVersion: undefined;
    };
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(() => {
      accountId = generateRecordId();
      signIn = {
        signedInAt: new Date(),
        timeZone: undefined,
        isFreeTrialUsedByEarlierAccount: false,
        agreedTermsVersion: undefined,
      };
      setUserSpy = mockSetUserOk();
    });

    test("Sentry の user の ID に付けること", async () => {
      await getAccountDurableObject(env, accountId).recordFirstSignIn(accountId, signIn);
      expect(setUserSpy).toHaveBeenCalledWith({ id: accountId });
    });
  });

  describe("東京で 2030-01-01 に最初のサインインを書いたとき", () => {
    let accountId: string;
    beforeEach(async () => {
      accountId = generateRecordId();
      // 張ったアラームがひとりでに動かないよう、先の時刻にしておく
      useFakeClock(Date.parse("2030-01-01T03:00:00Z"));
      await callRecordFirstSignIn(accountId);
    });

    // 無料体験の最後の日は 2030-01-30 で、あと3日の日は 2030-01-28
    test("課金の確かめの時刻（無料体験のあと3日の日の始まり）にアラームを張ること", async () => {
      expect(await readAlarm(accountId)).toBe(Date.parse("2030-01-27T15:00:00Z"));
    });
  });

  // アラームは、要求が記録を変えたかによらず、要求のあとにいつも仕事の並びから張り直す
  describe("要求を受けたとき", () => {
    let accountId: string;
    beforeEach(() => {
      accountId = generateRecordId();
      // 張ったアラームがひとりでに動かないよう、先の時刻にしておく
      useFakeClock(Date.parse("2030-01-01T03:00:00Z"));
      mockAccountRequestsOk();
    });

    describe("動かす仕事の無いアカウントに、古いアラームが張られているとき", () => {
      beforeEach(async () => {
        await armStaleAlarm(accountId);
      });

      for (const { name, call } of requestCalls) {
        test(`${name}のあと、アラームを外すこと`, async () => {
          await call(accountId);
          expect(await readAlarm(accountId)).toBeNull();
        });
      }
    });

    describe("2030-01-01 に東京で最初のサインインを書き、そのあと古いアラームが張られているとき", () => {
      beforeEach(async () => {
        await callRecordFirstSignIn(accountId);
        await armStaleAlarm(accountId);
      });

      for (const { name, call } of requestCalls) {
        test(`${name}のあと、課金の確かめの時刻に張り直すこと`, async () => {
          await call(accountId);
          expect(await readAlarm(accountId)).toBe(Date.parse("2030-01-27T15:00:00Z"));
        });
      }
    });
  });

  describe("記録を消す呼び出しに、受け口がアカウント ID を渡したとき", () => {
    let accountId: string;
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(() => {
      accountId = generateRecordId();
      setUserSpy = mockSetUserOk();
    });

    test("Sentry の user の ID に付けること", async () => {
      await getAccountDurableObject(env, accountId).deleteRecords(accountId);
      expect(setUserSpy).toHaveBeenCalledWith({ id: accountId });
    });
  });

  describe("アカウント ID の名前で得た Durable Object のアラームが動いたとき", () => {
    let accountId: string;
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(async () => {
      accountId = generateRecordId();
      const stub = getAccountDurableObject(env, accountId);
      // ひとりでに動かないよう、先の時刻に張ってから動かす
      await runInDurableObject(stub, (_, state) => state.storage.setAlarm(Date.now() + 3_600_000));
      setUserSpy = mockSetUserOk();
      await runDurableObjectAlarm(stub);
    });

    test("名前のアカウント ID を、Sentry の user の ID に付けること", () => {
      expect(setUserSpy).toHaveBeenCalledWith({ id: accountId });
    });
  });

  describe("名前の無い Durable Object のアラームが動いたとき", () => {
    let stub: DurableObjectStub;
    beforeEach(async () => {
      stub = env.ACCOUNT.get(env.ACCOUNT.newUniqueId());
      await runInDurableObject(stub, (_, state) => state.storage.setAlarm(Date.now() + 3_600_000));
    });

    test("例外にすること", async () => {
      await expect(runDurableObjectAlarm(stub)).rejects.toThrow("アカウント ID が読めない");
    });
  });

  // 口の答えの出来事は、どの入口のものも、送る前に利用状況の設定で絞る
  describe("出来事を返す入口を、本番のサーバーで呼んだとき", () => {
    let accountId: string;
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(() => {
      accountId = generateRecordId();
    });

    describe("利用状況を送らない設定のとき", () => {
      beforeEach(async () => {
        await saveSendsUsageData(accountId, false);
        await enableUsageEventSending(accountId);
        fetchSpy = mockPostHogCaptureEndpointOk();
        mockAccountRequestsOk();
      });

      describe("送る要求", () => {
        beforeEach(async () => {
          await callPushSyncWrites(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("取りに行く要求", () => {
        beforeEach(async () => {
          await callPullSyncChanges(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("写真を受け取る要求", () => {
        beforeEach(async () => {
          await callReceiveMealPhoto(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("目標の下見の要求", () => {
        beforeEach(async () => {
          await callPreviewGoalSetup(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("目標案の要求", () => {
        beforeEach(async () => {
          await callProposeGoals(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("自分で決める目標体重の要求", () => {
        beforeEach(async () => {
          await callAssessCustomTargetWeight(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("目標を決める要求", () => {
        beforeEach(async () => {
          await callDecideGoal(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("アラーム", () => {
        beforeEach(async () => {
          await runAlarm(accountId);
        });

        test("PostHog に送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });
    });

    describe("利用状況を送る設定のとき", () => {
      beforeEach(async () => {
        await saveSendsUsageData(accountId, true);
        await enableUsageEventSending(accountId);
        fetchSpy = mockPostHogCaptureEndpointOk();
        mockAccountRequestsOk();
      });

      describe("送る要求", () => {
        beforeEach(async () => {
          await callPushSyncWrites(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("取りに行く要求", () => {
        beforeEach(async () => {
          await callPullSyncChanges(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("写真を受け取る要求", () => {
        beforeEach(async () => {
          await callReceiveMealPhoto(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("目標の下見の要求", () => {
        beforeEach(async () => {
          await callPreviewGoalSetup(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("目標案の要求", () => {
        beforeEach(async () => {
          await callProposeGoals(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("自分で決める目標体重の要求", () => {
        beforeEach(async () => {
          await callAssessCustomTargetWeight(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("目標を決める要求", () => {
        beforeEach(async () => {
          await callDecideGoal(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });

      describe("アラーム", () => {
        beforeEach(async () => {
          await runAlarm(accountId);
        });

        test("口が返した出来事を PostHog に送ること", () => {
          expect(readPostHogCapturedEvents(fetchSpy).map(({ event }) => event)).toEqual([
            "meal_photo_receipt_failed",
          ]);
        });
      });
    });
  });
});

const saveSendsUsageData = (accountId: string, sendsUsageData: boolean) =>
  runInDurableObject(getAccountDurableObject(env, accountId), async (_, state) => {
    await durableObjectFactory(
      drizzle(state.storage, { schema: durableObjectTables }),
    ).accountSettings.create({ sendsUsageData });
  });

const clientState: SyncClientState = {
  deviceId: "device-1",
  timeZone: "Asia/Tokyo",
  appVersion: "1.0.0",
  osVersion: "26.0",
  pendingWriteCount: 0,
  oldestPendingWriteAgeSeconds: undefined,
  pendingPhotoCount: 0,
};

const goalSetupSituation = {
  timeZone: "Asia/Tokyo",
  preUseEnergyIntakes: [],
  bodyData: undefined,
};

const callRecordFirstSignIn = (accountId: string) =>
  getAccountDurableObject(env, accountId).recordFirstSignIn(accountId, {
    signedInAt: new Date(),
    timeZone: "Asia/Tokyo",
    isFreeTrialUsedByEarlierAccount: false,
    agreedTermsVersion: undefined,
  });

const readAlarm = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.getAlarm(),
  );

// 仕事の並びのどの時刻とも違う時刻
const armStaleAlarm = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.setAlarm(Date.parse("2030-01-02T00:00:00Z")),
  );

const callPushSyncWrites = (accountId: string) =>
  getAccountDurableObject(env, accountId).pushSyncWrites(accountId, {
    clientState,
    writes: [],
    isFinalBatch: true,
  });

const callPullSyncChanges = (accountId: string) =>
  getAccountDurableObject(env, accountId).pullSyncChanges(accountId, {
    clientState,
    afterSequence: 0,
  });

const callReceiveMealPhoto = (accountId: string) =>
  getAccountDurableObject(env, accountId).receiveMealPhoto(accountId, {
    photoId: generateRecordId(),
    photo: new ArrayBuffer(0),
  });

const callPreviewGoalSetup = (accountId: string) =>
  getAccountDurableObject(env, accountId).previewGoalSetup(
    accountId,
    { ...goalSetupSituation, direction: "maintain" },
    new Date(),
  );

const callProposeGoals = (accountId: string) =>
  getAccountDurableObject(env, accountId).proposeGoals(
    accountId,
    { ...goalSetupSituation, plan: { direction: "maintain" } },
    new Date(),
  );

const callAssessCustomTargetWeight = (accountId: string) =>
  getAccountDurableObject(env, accountId).assessCustomTargetWeight(
    accountId,
    { ...goalSetupSituation, direction: "lose", deadlineOn: "2026-12-31", targetWeightKg: 60 },
    new Date(),
  );

const callDecideGoal = (accountId: string) =>
  getAccountDurableObject(env, accountId).decideGoal(
    accountId,
    {
      ...goalSetupSituation,
      requestId: generateRecordId(),
      startedOn: "2026-10-21",
      choice: { type: "maintain" },
      shown: {
        targetWeightKg: 60,
        dailyGuide: { energyKcal: 2000, proteinG: 100, fatG: 60, carbohydrateG: 250 },
      },
      rejectedCustomTargetWeightCount: 0,
    },
    new Date(),
  );

// ひとりでに動かないよう、先の時刻に張ってから動かす
const runAlarm = async (accountId: string) => {
  const stub = getAccountDurableObject(env, accountId);
  await runInDurableObject(stub, (_, state) => state.storage.setAlarm(Date.now() + 3_600_000));
  await runDurableObjectAlarm(stub);
};

const callReadMealPhoto = (accountId: string) =>
  getAccountDurableObject(env, accountId).readMealPhoto(accountId, generateRecordId());

const callFindLastEstimationAttemptConclusionOfMeal = (accountId: string) =>
  getAccountDurableObject(env, accountId).findLastEstimationAttemptConclusionOfMeal(
    accountId,
    generateRecordId(),
  );

const callWatchReply = (accountId: string) =>
  getAccountDurableObject(env, accountId).watchReply(accountId, generateRecordId());

const callFindTermsAgreementRequirement = (accountId: string) =>
  getAccountDurableObject(env, accountId).findTermsAgreementRequirement(accountId);

const callAgreeToTerms = (accountId: string) =>
  getAccountDurableObject(env, accountId).agreeToTerms(accountId, {
    requestId: generateRecordId(),
    termsVersion: "unknown",
  });

// 口を偽物に差し替えて呼ぶので、取引の中身は答えに効かない
const transaction = {
  environment: "sandbox",
  appStoreOriginalTransactionId: "1",
  appStoreTransactionId: "1",
  appStoreProductId: "app.nu-tori.subscription.monthly",
  transactionReason: "purchase",
  purchasedAt: new Date("2030-01-01T03:00:00Z"),
  expiresAt: new Date("2030-02-01T03:00:00Z"),
  appAccountToken: undefined,
  revokedAt: undefined,
} as const;

const callReportSubscriptionTransaction = (accountId: string) =>
  getAccountDurableObject(env, accountId).reportSubscriptionTransaction(accountId, {
    requestId: generateRecordId(),
    trigger: "purchase",
    transaction,
  });

const callReceiveAppStoreServerNotification = (accountId: string) =>
  getAccountDurableObject(env, accountId).receiveAppStoreServerNotification(accountId, {
    notificationUuid: generateRecordId(),
    notificationType: "DID_RENEW",
    notificationSubtype: undefined,
    signedAt: new Date("2030-01-01T03:00:00Z"),
    transaction,
    gracePeriodExpiresAt: undefined,
  });

// 受け口から呼ぶ要求の全部。記録を消す要求は、表ごと消すので張り直さない
const requestCalls: { name: string; call: (accountId: string) => Promise<unknown> }[] = [
  { name: "送る要求", call: callPushSyncWrites },
  { name: "取りに行く要求", call: callPullSyncChanges },
  { name: "写真を受け取る要求", call: callReceiveMealPhoto },
  { name: "写真を読む要求", call: callReadMealPhoto },
  {
    name: "最後の推定の試みの結論を読む要求",
    call: callFindLastEstimationAttemptConclusionOfMeal,
  },
  { name: "見守る要求", call: callWatchReply },
  { name: "目標の下見の要求", call: callPreviewGoalSetup },
  { name: "目標案の要求", call: callProposeGoals },
  { name: "自分で決める目標体重の要求", call: callAssessCustomTargetWeight },
  { name: "目標を決める要求", call: callDecideGoal },
  { name: "規約への同意が要るかを読む要求", call: callFindTermsAgreementRequirement },
  { name: "規約に同意する要求", call: callAgreeToTerms },
  { name: "取引の知らせ", call: callReportSubscriptionTransaction },
  { name: "App Store のサーバー通知", call: callReceiveAppStoreServerNotification },
];
