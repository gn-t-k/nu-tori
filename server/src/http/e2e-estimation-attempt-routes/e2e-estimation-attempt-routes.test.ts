import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { app } from "../app";

const secret = "e2e-sign-in-secret-0123456789abcdef0123456789";

describe("確かめのジョブのための、食事の最後に終わった推定の試みを読む口", () => {
  let testEnv: Env;
  let request: Parameters<typeof readLastEstimationAttempt>[1];

  describe("開発用の環境で、秘密の値が置かれているとき", () => {
    beforeEach(async () => {
      testEnv = { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: secret };
      request = {
        mealId: generateRecordId(),
        sentSecret: secret,
        sessionToken: await signInForE2e(testEnv),
      };
    });

    describe("推定を始めていない食事を読んだとき", () => {
      test("終わった試みが無いと返すこと", async () => {
        const response = await readLastEstimationAttempt(testEnv, request);
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { lastEndedAttempt: null },
        });
      });
    });

    describe("食事の ID が UUID の正規形でないとき", () => {
      beforeEach(() => {
        request = { ...request, mealId: "not-a-uuid" };
      });

      test("400 を返すこと", async () => {
        const response = await readLastEstimationAttempt(testEnv, request);
        expect(response.status).toBe(400);
      });
    });

    describe("違う秘密の値を送ったとき", () => {
      beforeEach(() => {
        request = { ...request, sentSecret: `${secret}x` };
      });

      test("401 を返すこと", async () => {
        const response = await readLastEstimationAttempt(testEnv, request);
        expect(response.status).toBe(401);
      });
    });

    describe("セッションを送らないとき", () => {
      beforeEach(() => {
        request = { ...request, sessionToken: undefined };
      });

      test("401 を返すこと", async () => {
        const response = await readLastEstimationAttempt(testEnv, request);
        expect(response.status).toBe(401);
      });
    });
  });

  describe("本番の環境で、秘密の値が置かれてしまったとき", () => {
    beforeEach(async () => {
      request = {
        mealId: generateRecordId(),
        sentSecret: secret,
        sessionToken: await signInForE2e({
          ...env,
          SENTRY_ENVIRONMENT: "development",
          E2E_SIGN_IN_SECRET: secret,
        }),
      };
      testEnv = { ...env, SENTRY_ENVIRONMENT: "production", E2E_SIGN_IN_SECRET: secret };
    });

    test("正しい秘密の値を送っても、口が無いのと同じ 404 を返すこと", async () => {
      const response = await readLastEstimationAttempt(testEnv, request);
      expect(response.status).toBe(404);
    });
  });
});

const signInForE2e = async (signInEnv: Env): Promise<string> => {
  const response = await app.request(
    "/v1/e2e/sessions",
    { method: "POST", headers: { "x-e2e-sign-in-secret": secret } },
    signInEnv,
  );
  return (await response.json<{ sessionToken: string }>()).sessionToken;
};

const readLastEstimationAttempt = (
  requestEnv: Env,
  request: { mealId: string; sentSecret: string; sessionToken: string | undefined },
) =>
  app.request(
    `/v1/e2e/meals/${request.mealId}/last-estimation-attempt`,
    {
      headers: {
        "x-e2e-sign-in-secret": request.sentSecret,
        ...(request.sessionToken === undefined
          ? {}
          : { authorization: `Bearer ${request.sessionToken}` }),
      },
    },
    requestEnv,
  );
