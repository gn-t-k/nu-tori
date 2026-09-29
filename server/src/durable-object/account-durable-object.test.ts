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
});
