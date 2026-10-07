import { env } from "cloudflare:workers";
import { Hono } from "hono";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { mockSetUserOk } from "../../observability/set-user.mock";
import {
  mockAccountRateLimiterError,
  mockAccountRateLimiterOk,
  signInTestAccount,
} from "../testing";
import { authenticateAccount } from "./index";

describe("セッションと回数の歯止め", () => {
  describe("セッションが無いとき", () => {
    let protectedApp: Hono<{ Bindings: Env; Variables: { accountId: string } }>;
    beforeEach(() => {
      protectedApp = createProtectedApp();
    });

    test("401 を返すこと", async () => {
      const response = await protectedApp.request("/", {}, env);
      expect(response.status).toBe(401);
    });
  });

  describe("セッションのトークンを Bearer で送ったとき", () => {
    let protectedApp: Hono<{ Bindings: Env; Variables: { accountId: string } }>;
    let signedIn: { accountId: string; sessionToken: string };
    let limitSpy: ReturnType<typeof mockAccountRateLimiterOk>;
    beforeEach(async () => {
      protectedApp = createProtectedApp();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      signedIn = await signInTestAccount(generateRecordId());
      limitSpy = mockAccountRateLimiterOk();
    });

    test("アカウント ID を後ろに渡すこと", async () => {
      const response = await protectedApp.request(
        "/",
        { headers: { authorization: `Bearer ${signedIn.sessionToken}` } },
        env,
      );
      expect(await response.text()).toBe(signedIn.accountId);
    });

    test("アカウント ID ごとに回数を数えること", async () => {
      await protectedApp.request(
        "/",
        { headers: { authorization: `Bearer ${signedIn.sessionToken}` } },
        env,
      );
      expect(limitSpy).toHaveBeenCalledWith({ key: signedIn.accountId });
    });
  });

  describe("セッションのトークンを付けて、メソッドごとに要求したとき", () => {
    let protectedApp: Hono<{ Bindings: Env; Variables: { accountId: string } }>;
    let signedIn: { accountId: string; sessionToken: string };
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    beforeEach(async () => {
      protectedApp = createProtectedApp();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      signedIn = await signInTestAccount(generateRecordId());
      mockAccountRateLimiterOk();
      setUserSpy = mockSetUserOk();
    });

    describe("GET の要求のとき", () => {
      beforeEach(async () => {
        await protectedApp.request(
          "/",
          { headers: { authorization: `Bearer ${signedIn.sessionToken}` } },
          env,
        );
      });

      test("Sentry の user にアカウント ID を付けること", () => {
        expect(setUserSpy).toHaveBeenCalledWith({ id: signedIn.accountId });
      });
    });

    describe("HEAD の要求のとき", () => {
      beforeEach(async () => {
        await protectedApp.request(
          "/",
          { method: "HEAD", headers: { authorization: `Bearer ${signedIn.sessionToken}` } },
          env,
        );
      });

      test("Sentry の user を付けないこと", () => {
        expect(setUserSpy).not.toHaveBeenCalled();
      });
    });

    describe("OPTIONS の要求のとき", () => {
      beforeEach(async () => {
        await protectedApp.request(
          "/",
          { method: "OPTIONS", headers: { authorization: `Bearer ${signedIn.sessionToken}` } },
          env,
        );
      });

      test("Sentry の user を付けないこと", () => {
        expect(setUserSpy).not.toHaveBeenCalled();
      });
    });
  });

  describe("回数の歯止めにかかったとき", () => {
    let protectedApp: Hono<{ Bindings: Env; Variables: { accountId: string } }>;
    let sessionToken: string;
    beforeEach(async () => {
      protectedApp = createProtectedApp();
      mockAppleKeysEndpointOk();
      mockExchangeAppleAuthorizationCodeOk();
      ({ sessionToken } = await signInTestAccount(generateRecordId()));
      mockAccountRateLimiterError();
    });

    test("429 を返すこと", async () => {
      const response = await protectedApp.request(
        "/",
        { headers: { authorization: `Bearer ${sessionToken}` } },
        env,
      );
      expect(response.status).toBe(429);
    });
  });
});

const createProtectedApp = () =>
  new Hono<{ Bindings: Env; Variables: { accountId: string } }>()
    .use(authenticateAccount)
    .get("/", (c) => c.text(c.var.accountId));
