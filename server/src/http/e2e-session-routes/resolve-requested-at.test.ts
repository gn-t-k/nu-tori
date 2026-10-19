import { beforeEach, describe, expect, test } from "vitest";
import { env } from "cloudflare:workers";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { recordDailyWeights } from "../goal-setup-routes/testing/record-daily-weights";
import { app } from "../app";
import { signInTestAccount } from "../testing";

const secret = "e2e-sign-in-secret-0123456789abcdef0123456789";

// 確かめのジョブは、目標の設定の要求を過去の時刻に送ったことにして、新しいアカウントに前の週を作る。
// 差し替えた時刻は、目標案の開始の日（その時刻の、要求のタイムゾーンでの日）で見る
describe("確かめのジョブのための、目標の設定の要求の時刻の差し替え", () => {
  let sessionToken: string;
  // 体重を量った日と、差し替える時刻の日（日本時間）。今日より前の日にする
  const weighedOn = "2026-01-04";
  const requestedAt = "2026-01-05T03:00:00.000Z";
  let today: string;
  const proposeMaintenance = (testEnv: Env, headers: Record<string, string>) =>
    app.request(
      "/v1/goal-setup/proposals",
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${sessionToken}`,
          "content-type": "application/json",
          ...headers,
        },
        body: JSON.stringify({
          timeZone: "Asia/Tokyo",
          plan: { direction: "maintain" },
          // 作り話の身体データ（公開リポジトリ）
          bodyData: {
            sex: "female",
            heightCentimeters: 160,
            ageYears: 35,
            activity: { type: "level", level: "standing" },
          },
        }),
      },
      testEnv,
    );
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(generateRecordId(), { timeZone: "Asia/Tokyo" }));
    // 準備と要求のあいだに日付が変わらないよう、時計を止める
    useFakeClock(Date.now());
    today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    await recordDailyWeights(sessionToken, [weighedOn], 60.5);
  });

  describe("開発用の環境で、秘密の値と時刻を送ったとき", () => {
    test("その時刻に送ったことにすること", async () => {
      const response = await proposeMaintenance(
        { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: secret },
        { "x-e2e-sign-in-secret": secret, "x-e2e-requested-at": requestedAt },
      );
      expect(await readStartedOn(response)).toBe("2026-01-05");
    });
  });

  describe("開発用の環境で、違う秘密の値と時刻を送ったとき", () => {
    test("差し替えず、今の時刻にすること", async () => {
      const response = await proposeMaintenance(
        { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: secret },
        { "x-e2e-sign-in-secret": `${secret}x`, "x-e2e-requested-at": requestedAt },
      );
      expect(await readStartedOn(response)).toBe(today);
    });
  });

  describe("開発用の環境で、読めない時刻を送ったとき", () => {
    test("差し替えず、今の時刻にすること", async () => {
      const response = await proposeMaintenance(
        { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: secret },
        { "x-e2e-sign-in-secret": secret, "x-e2e-requested-at": "yesterday" },
      );
      expect(await readStartedOn(response)).toBe(today);
    });
  });

  describe("本番の環境で、秘密の値が置かれてしまい、それと時刻を送ったとき", () => {
    test("差し替えず、今の時刻にすること", async () => {
      const response = await proposeMaintenance(
        { ...env, SENTRY_ENVIRONMENT: "production", E2E_SIGN_IN_SECRET: secret },
        { "x-e2e-sign-in-secret": secret, "x-e2e-requested-at": requestedAt },
      );
      expect(await readStartedOn(response)).toBe(today);
    });
  });
});

const readStartedOn = async (response: Response) =>
  (await response.json<{ startedOn: string }>()).startedOn;
