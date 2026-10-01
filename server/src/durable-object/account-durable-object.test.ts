import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockSetUserOk } from "../observability/set-user.mock";
import { getAccountDurableObject } from "./get-account-durable-object";

describe("アカウントの Durable Object", () => {
  describe("使い始めた日を決める呼び出しに、受け口がアカウント ID を渡したとき", () => {
    let accountId: string;
    let signIn: { signedInAt: Date; timeZone: string | undefined };
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(() => {
      accountId = crypto.randomUUID();
      signIn = { signedInAt: new Date(), timeZone: undefined };
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
      accountId = crypto.randomUUID();
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
      accountId = crypto.randomUUID();
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
});
