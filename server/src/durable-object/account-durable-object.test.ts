import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockAccountRequestsOk } from "../account/domain/account-requests.mock";
import { generateRecordId } from "../domain/record-id";
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
    };
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(() => {
      accountId = generateRecordId();
      signIn = {
        signedInAt: new Date(),
        timeZone: undefined,
        isFreeTrialUsedByEarlierAccount: false,
      };
      setUserSpy = mockSetUserOk();
    });

    test("Sentry の user の ID に付けること", async () => {
      await getAccountDurableObject(env, accountId).recordFirstSignIn(accountId, signIn);
      expect(setUserSpy).toHaveBeenCalledWith({ id: accountId });
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
