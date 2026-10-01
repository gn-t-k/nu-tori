import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import wranglerConfig from "../../../wrangler.jsonc?raw";
import { app } from "../app";
import { pullSyncChanges } from "../sync-routes/testing/pull-sync-changes";

const secret = "e2e-sign-in-secret-0123456789abcdef0123456789";

describe("確かめのジョブのためのサインインの口", () => {
  describe("開発用の環境で、秘密の値が置かれているとき", () => {
    let developmentEnv: Env;
    beforeEach(() => {
      developmentEnv = { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: secret };
    });

    describe("正しい秘密の値を送ったとき", () => {
      test("サインインして、使えるセッションを返すこと", async () => {
        const response = await signInForE2e(developmentEnv, secret);
        const { sessionToken } = await response.json<{ sessionToken: string }>();
        const pulled = await pullSyncChanges(sessionToken);
        expect({ status: response.status, pulledStatus: pulled.status }).toEqual({
          status: 201,
          pulledStatus: 200,
        });
      });

      test("呼ぶたびに別のアカウントを作ること", async () => {
        const first = await (
          await signInForE2e(developmentEnv, secret)
        ).json<{ accountId: string }>();
        const second = await (
          await signInForE2e(developmentEnv, secret)
        ).json<{ accountId: string }>();
        expect(first.accountId).not.toBe(second.accountId);
      });

      test("使い始めた日を決めること", async () => {
        const { sessionToken } = await (
          await signInForE2e(developmentEnv, secret)
        ).json<{ sessionToken: string }>();
        const pulled = await (
          await pullSyncChanges(sessionToken)
        ).json<{ startedOn: string | null }>();
        expect(pulled.startedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      });
    });

    describe("違う秘密の値を送ったとき", () => {
      test("401 を返すこと", async () => {
        const response = await signInForE2e(developmentEnv, `${secret}x`);
        expect(response.status).toBe(401);
      });
    });

    describe("秘密の値を送らないとき", () => {
      test("401 を返すこと", async () => {
        const response = await signInForE2e(developmentEnv, undefined);
        expect(response.status).toBe(401);
      });
    });
  });

  describe("本番の環境で、秘密の値が置かれてしまったとき", () => {
    let productionEnv: Env;
    beforeEach(() => {
      productionEnv = { ...env, SENTRY_ENVIRONMENT: "production", E2E_SIGN_IN_SECRET: secret };
    });

    test("正しい秘密の値を送っても、口が無いのと同じ 404 を返すこと", async () => {
      const response = await signInForE2e(productionEnv, secret);
      expect(response.status).toBe(404);
    });
  });

  describe("開発用の環境で、秘密の値が置かれていないとき", () => {
    test("口が無いのと同じ 404 を返すこと", async () => {
      const response = await signInForE2e({ ...env, E2E_SIGN_IN_SECRET: undefined }, "");
      expect(response.status).toBe(404);
    });
  });

  describe("開発用の環境で、秘密の値が短すぎるとき", () => {
    test("推測されやすいので、口を閉じて 404 を返すこと", async () => {
      const response = await signInForE2e({ ...env, E2E_SIGN_IN_SECRET: "short" }, "short");
      expect(response.status).toBe(404);
    });
  });

  describe("設定（wrangler.jsonc）", () => {
    test("秘密の値の名前を、本番の環境に書いていないこと", () => {
      const productionPart = wranglerConfig.slice(wranglerConfig.indexOf('"env"'));
      expect(productionPart).not.toContain("E2E_SIGN_IN_SECRET");
    });

    test("口を開く環境の名前（development）を、本番の環境に書いていないこと", () => {
      const productionPart = wranglerConfig.slice(wranglerConfig.indexOf('"env"'));
      expect(productionPart).not.toContain('"development"');
    });
  });
});

const signInForE2e = (testEnv: Env, sentSecret: string | undefined) =>
  app.request(
    "/v1/e2e/sessions",
    {
      method: "POST",
      headers: sentSecret === undefined ? {} : { "x-e2e-sign-in-secret": sentSecret },
    },
    testEnv,
  );
