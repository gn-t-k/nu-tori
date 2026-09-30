import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { createAppleRefreshTokenStore } from "../../auth/create-apple-refresh-token-store";
import { createAuthentication } from "../../auth/create-authentication";
import { AppleAuthorizationCodeRejectedError } from "../../auth/exchange-apple-authorization-code";
import {
  mockExchangeAppleAuthorizationCodeError,
  mockExchangeAppleAuthorizationCodeOk,
} from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk, signAppleIdToken } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { app } from "../app";
import { signInTestAccount, signInWithApple } from "../testing";
import { sha256Hex } from "../testing/sha256-hex";

describe("サインイン", () => {
  describe("ID トークンと認可コードを受け付けたとき", () => {
    let appleUserId: string;
    beforeEach(() => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk({ refreshToken: "apple-refresh-token" });
    });

    test("以後の要求に使えるセッションのトークンを返すこと", async () => {
      const response = await signInWithApple(appleUserId);
      const { sessionToken } = await response.json<{ sessionToken: string }>();
      const session = await createAuthentication(env, "http://localhost").api.getSession({
        headers: new Headers({ authorization: `Bearer ${sessionToken}` }),
      });
      expect({ status: response.status, signedIn: session !== null }).toEqual({
        status: 201,
        signedIn: true,
      });
    });

    test("アカウント ID を返すこと", async () => {
      const response = await signInWithApple(appleUserId);
      const { accountId } = await response.json<{ accountId: string }>();
      const account = await env.DB.prepare(
        `SELECT "userId" FROM account WHERE "providerId" = 'apple' AND "accountId" = ?`,
      )
        .bind(appleUserId)
        .first<{ userId: string }>();
      expect(accountId).toBe(account?.userId);
    });

    test("Apple の refresh token を保存すること", async () => {
      const { accountId } = await signInTestAccount(appleUserId);
      const refreshToken = await createAppleRefreshTokenStore(
        env.DB,
        env.APPLE_REFRESH_TOKEN_KEYS,
      ).find(accountId);
      expect(refreshToken).toBe("apple-refresh-token");
    });
  });

  describe("同じ Apple ID でサインインしたことがあるとき", () => {
    let appleUserId: string;
    let accountId: string;
    beforeEach(async () => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ accountId } = await signInTestAccount(appleUserId));
    });

    test("同じアカウントに入ること", async () => {
      const signedInAgain = await signInTestAccount(appleUserId);
      expect(signedInAgain.accountId).toBe(accountId);
    });

    test("Apple のメールと ID トークンを保存しないこと", async () => {
      await signInWithApple(appleUserId);
      const saved = await env.DB.prepare(
        `SELECT "user"."email", account."idToken" FROM "user"
         JOIN account ON account."userId" = "user"."id" WHERE "user"."id" = ?`,
      )
        .bind(accountId)
        .first<{ email: string; idToken: string | null }>();
      expect(saved).toEqual({ email: expect.stringMatching(/@nu-tori\.invalid$/), idToken: null });
    });
  });

  describe("ID トークンの nonce が送った nonce と違うとき", () => {
    let body: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      body = JSON.stringify({
        idToken: await signAppleIdToken({ appleUserId: crypto.randomUUID(), nonce: "nonce-1" }),
        nonce: "nonce-2",
        authorizationCode: "authorization-code",
      });
    });

    test("401 を返すこと", async () => {
      const response = await app.request(
        "/v1/sessions",
        { method: "POST", headers: { "content-type": "application/json" }, body },
        env,
      );
      expect(response.status).toBe(401);
    });
  });

  describe("ID トークンの nonce が送った nonce そのもののとき", () => {
    let body: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      const nonce = "nonce-1";
      body = JSON.stringify({
        idToken: await signAppleIdToken({ appleUserId: crypto.randomUUID(), nonce }),
        nonce,
        authorizationCode: "authorization-code",
      });
    });

    test("401 を返すこと", async () => {
      const response = await app.request(
        "/v1/sessions",
        { method: "POST", headers: { "content-type": "application/json" }, body },
        env,
      );
      expect(response.status).toBe(401);
    });
  });

  describe("ID トークンの nonce が送った nonce の SHA-256 の小文字の16進のとき", () => {
    let body: string;
    beforeEach(async () => {
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      const nonce = "nonce-1";
      body = JSON.stringify({
        idToken: await signAppleIdToken({
          appleUserId: crypto.randomUUID(),
          nonce: await sha256Hex(nonce),
        }),
        nonce,
        authorizationCode: "authorization-code",
      });
    });

    test("201 を返すこと", async () => {
      const response = await app.request(
        "/v1/sessions",
        { method: "POST", headers: { "content-type": "application/json" }, body },
        env,
      );
      expect(response.status).toBe(201);
    });
  });

  describe("Apple が認可コードを受け付けなかったとき", () => {
    let appleUserId: string;
    beforeEach(() => {
      appleUserId = crypto.randomUUID();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeError(new AppleAuthorizationCodeRejectedError());
    });

    test("401 を返すこと", async () => {
      const response = await signInWithApple(appleUserId);
      expect(response.status).toBe(401);
    });
  });

  describe("使い始めた日", () => {
    afterEach(() => {
      vi.useRealTimers();
    });

    describe("端末のタイムゾーンが届いたとき", () => {
      let appleUserId: string;
      let timeZone: string;
      beforeEach(() => {
        appleUserId = crypto.randomUUID();
        timeZone = "Asia/Tokyo";
        mockAppleKeysEndpointOk();
        mockExchangeAppleAuthorizationCodeOk();
        vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-09-29T20:00:00Z") });
      });

      test("そのタイムゾーンでの日付を使い始めた日にすること", async () => {
        const { accountId } = await signInTestAccount(appleUserId, { timeZone });
        expect(await readFirstSignIn(accountId)).toEqual({
          started_on: "2026-09-30",
          signed_in_at: new Date("2026-09-29T20:00:00Z").getTime(),
          time_zone: "Asia/Tokyo",
        });
      });
    });

    describe("端末のタイムゾーンが届かないとき", () => {
      let appleUserId: string;
      beforeEach(() => {
        appleUserId = crypto.randomUUID();
        mockAppleKeysEndpointOk();
        mockExchangeAppleAuthorizationCodeOk();
        vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-09-29T20:00:00Z") });
      });

      test("UTC の日付を使い始めた日にし、タイムゾーンは空のままにすること", async () => {
        const { accountId } = await signInTestAccount(appleUserId);
        expect(await readFirstSignIn(accountId)).toEqual({
          started_on: "2026-09-29",
          signed_in_at: new Date("2026-09-29T20:00:00Z").getTime(),
          time_zone: null,
        });
      });
    });

    describe("端末のタイムゾーンが IANA の名前として読めないとき", () => {
      let appleUserId: string;
      let timeZone: string;
      beforeEach(() => {
        appleUserId = crypto.randomUUID();
        timeZone = "Tokyo/Nowhere";
        mockAppleKeysEndpointOk();
        mockExchangeAppleAuthorizationCodeOk();
        vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-09-29T20:00:00Z") });
      });

      test("届かなかったときと同じに扱い、サインインを受け付けること", async () => {
        const { accountId } = await signInTestAccount(appleUserId, { timeZone });
        expect(await readFirstSignIn(accountId)).toEqual({
          started_on: "2026-09-29",
          signed_in_at: new Date("2026-09-29T20:00:00Z").getTime(),
          time_zone: null,
        });
      });
    });

    describe("使い始めた日がすでに決まっているとき", () => {
      let appleUserId: string;
      let accountId: string;
      let secondTimeZone: string;
      beforeEach(async () => {
        appleUserId = crypto.randomUUID();
        secondTimeZone = "America/Los_Angeles";
        mockAppleKeysEndpointOk();
        mockExchangeAppleAuthorizationCodeOk();
        vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-09-29T20:00:00Z") });
        ({ accountId } = await signInTestAccount(appleUserId, { timeZone: "Asia/Tokyo" }));
        vi.setSystemTime(new Date("2026-10-05T03:00:00Z"));
      });

      test("2回目のサインインで変わらないこと", async () => {
        await signInTestAccount(appleUserId, { timeZone: secondTimeZone });
        expect(await readFirstSignIn(accountId)).toEqual({
          started_on: "2026-09-30",
          signed_in_at: new Date("2026-09-29T20:00:00Z").getTime(),
          time_zone: "Asia/Tokyo",
        });
      });
    });

    describe("認可コードの交換に失敗してアカウントだけ先にできたとき", () => {
      let appleUserId: string;
      let timeZone: string;
      beforeEach(async () => {
        appleUserId = crypto.randomUUID();
        timeZone = "Asia/Tokyo";
        mockAppleKeysEndpointOk();
        vi.useFakeTimers({ toFake: ["Date"], now: new Date("2026-09-29T20:00:00Z") });
        mockExchangeAppleAuthorizationCodeError(new AppleAuthorizationCodeRejectedError());
        await signInWithApple(appleUserId);
        vi.setSystemTime(new Date("2026-10-05T03:00:00Z"));
        mockExchangeAppleAuthorizationCodeOk();
      });

      test("次に成功したサインインの日を使い始めた日にすること", async () => {
        const { accountId } = await signInTestAccount(appleUserId, { timeZone });
        expect(await readFirstSignIn(accountId)).toEqual({
          started_on: "2026-10-05",
          signed_in_at: new Date("2026-10-05T03:00:00Z").getTime(),
          time_zone: "Asia/Tokyo",
        });
      });
    });

    describe("認可コードの交換に失敗したとき", () => {
      let appleUserId: string;
      beforeEach(() => {
        appleUserId = crypto.randomUUID();
        mockAppleKeysEndpointOk();
        mockExchangeAppleAuthorizationCodeError(new AppleAuthorizationCodeRejectedError());
      });

      test("使い始めた日を決めないこと", async () => {
        await signInWithApple(appleUserId);
        const account = await env.DB.prepare(
          `SELECT "userId" FROM account WHERE "providerId" = 'apple' AND "accountId" = ?`,
        )
          .bind(appleUserId)
          .first<{ userId: string }>();
        expect(await readFirstSignIn(account?.userId ?? "")).toBeUndefined();
      });
    });
  });
});

const readFirstSignIn = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.sql
      .exec("SELECT started_on, signed_in_at, time_zone FROM first_sign_ins")
      .toArray()
      .at(0),
  );
