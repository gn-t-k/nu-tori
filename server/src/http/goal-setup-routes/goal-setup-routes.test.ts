import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { generateRecordId } from "../../domain/record-id";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import { putMealPhoto } from "../meal-photo-routes/testing/put-meal-photo";
import { pushSyncWrites } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { signInTestAccount } from "../testing";
import { postGoalSetup } from "./testing/post-goal-setup";
import { readAllStoredRows } from "./testing/read-all-stored-rows";
import { recordDailyWeights } from "./testing/record-daily-weights";

describe("目標の設定の要求", () => {
  let accountId: string;
  let sessionToken: string;
  // 端末のタイムゾーン（日本時間）での今日
  let today: string;
  // 初期値の窓（今日を除く直前の 28 日）
  let windowDays: string[];
  // 開始の日から数えて 91 日め（13 週）の期限
  let deadlineOn: string;
  let seed: (
    rows: (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>,
  ) => Promise<void>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId(), {
      timeZone: "Asia/Tokyo",
    }));
    // 時計を、サインインのちょうど1日あとで止める。使い始めた日が昨日になり、準備と要求のあいだに日付が変わらない
    useFakeClock(Date.now() + 86_400_000);
    today = computeCalendarDayInTimeZone(new Date(), "Asia/Tokyo");
    windowDays = Array.from({ length: 28 }, (_, index) => addDays(today, index - 28));
    deadlineOn = addDays(today, 90);
    seed = (rows) =>
      runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
        rows(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables }))),
      );
  });

  describe("初めての目標で、初期値の窓に体重記録と使い始める前の摂取エネルギーが揃っているとき", () => {
    // 体重が 70 kg のまま変わらないので、推定消費カロリーは食べた量の平均になる
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 }));
    });

    describe("減量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "lose",
          preUseEnergyIntakes,
        });
      });

      test("逆算できることと、案を出せることを返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { canBackCalculate: true, canOfferLoseProposals: true },
        });
      });
    });

    describe("増量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "gain",
          preUseEnergyIntakes,
        });
      });

      test("逆算できることだけを返すこと", async () => {
        expect(await response.json()).toEqual({ canBackCalculate: true });
      });
    });

    describe("減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
          preUseEnergyIntakes,
        });
      });

      test("開始の日、3つの枠、受け付ける幅、逆算した推定消費カロリー、使った体重の傾向と最後の体重記録の日を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: {
            startedOn: today,
            direction: "lose",
            deadlineOn,
            expenditureKcal: 2400,
            expenditureSource: "back_calculated",
            startingWeightTrendKg: 70,
            lastWeightRecordedOn: addDays(today, -1),
            proposals: [
              {
                pace: "gentle",
                status: "offered",
                targetWeightKg: 67.8,
                dailyGuide: { energyKcal: 2200, proteinG: 110, fatG: 60, carbohydrateG: 305 },
                difficulty: "gentle",
                dailyGuideDifferenceKcal: -200,
              },
              {
                pace: "standard",
                status: "offered",
                targetWeightKg: 65.5,
                dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
                difficulty: "standard",
                dailyGuideDifferenceKcal: -400,
              },
              {
                pace: "hard",
                status: "offered",
                targetWeightKg: 63.2,
                dailyGuide: { energyKcal: 1800, proteinG: 100, fatG: 50, carbohydrateG: 240 },
                difficulty: "hard",
                dailyGuideDifferenceKcal: -600,
              },
            ],
            acceptedTargetWeightRange: {
              minimumKg: 63.2,
              maximumKg: 69.9,
              fastestEndReason: "pace_too_fast",
            },
          },
        });
      });
    });

    describe("維持の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "maintain",
          preUseEnergyIntakes,
        });
      });

      test("開始の日の体重の傾向を目標体重にした、1日の目安と P・F・C の目安を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: {
            startedOn: today,
            direction: "maintain",
            expenditureKcal: 2400,
            expenditureSource: "back_calculated",
            startingWeightTrendKg: 70,
            lastWeightRecordedOn: addDays(today, -1),
            maintenance: {
              targetWeightKg: 70,
              dailyGuide: { energyKcal: 2400, proteinG: 110, fatG: 65, carbohydrateG: 345 },
            },
          },
        });
      });
    });

    describe("受け付ける幅の中の目標体重を、自分で決めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 65,
          preUseEnergyIntakes,
        });
      });

      test("1日の目安、P・F・C の目安、大変さを返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: {
            startedOn: today,
            status: "accepted",
            dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
            difficulty: "hard",
            dailyGuideDifferenceKcal: -400,
          },
        });
      });
    });

    describe("ハード案より速い目標体重を、自分で決めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 60,
          preUseEnergyIntakes,
        });
      });

      test("受け付けず、いちばん近い目標体重と、速すぎるという理由を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: {
            startedOn: today,
            status: "rejected",
            rejectionReason: "pace_too_fast",
            nearestAcceptedTargetWeightKg: 63.2,
          },
        });
      });
    });

    describe("減量で、体重の傾向より重い目標体重を、自分で決めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 70.5,
          preUseEnergyIntakes,
        });
      });

      test("受け付けず、いちばん近い目標体重と、向きの側に出ないという理由を返すこと", async () => {
        expect(await response.json()).toEqual({
          startedOn: today,
          status: "rejected",
          rejectionReason: "not_on_direction_side",
          nearestAcceptedTargetWeightKg: 69.9,
        });
      });
    });
  });

  describe("初めての目標で、逆算した推定消費カロリーが下限の 1,200 kcal に近いとき", () => {
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays.map((calendarDay) => ({ calendarDay, kcal: 1300 }));
    });

    describe("減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
          preUseEnergyIntakes,
        });
      });

      test("速さを落とした案と、出せない枠の理由と、下限で決まる受け付ける幅を返すこと", async () => {
        expect(await response.json()).toMatchObject({
          proposals: [
            {
              pace: "gentle",
              status: "offered",
              targetWeightKg: 68.9,
              dailyGuide: { energyKcal: 1200, proteinG: 105, fatG: 35, carbohydrateG: 115 },
              difficulty: "gentle",
              dailyGuideDifferenceKcal: -100,
            },
            {
              pace: "standard",
              status: "unavailable",
              unavailableReason: "daily_guide_below_minimum",
            },
            { pace: "hard", status: "unavailable", unavailableReason: "daily_guide_below_minimum" },
          ],
          acceptedTargetWeightRange: {
            minimumKg: 68.9,
            maximumKg: 69.9,
            fastestEndReason: "daily_guide_below_minimum",
          },
        });
      });
    });

    describe("1日の目安が下限を下回る目標体重を、自分で決めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 68,
          preUseEnergyIntakes,
        });
      });

      test("受け付けず、いちばん近い目標体重と、下限という理由を返すこと", async () => {
        expect(await response.json()).toEqual({
          startedOn: today,
          status: "rejected",
          rejectionReason: "daily_guide_below_minimum",
          nearestAcceptedTargetWeightKg: 68.9,
        });
      });
    });
  });

  describe("初めての目標で、逆算した推定消費カロリーが下限の 1,200 kcal のとき", () => {
    let response: Response;
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      response = await postGoalSetup(sessionToken, "preview", {
        direction: "lose",
        preUseEnergyIntakes: windowDays.map((calendarDay) => ({ calendarDay, kcal: 1200 })),
      });
    });

    test("減量の下見が、案を1つも出せないことを返すこと", async () => {
      expect(await response.json()).toEqual({
        canBackCalculate: true,
        canOfferLoseProposals: false,
      });
    });
  });

  describe("初めての目標で、使い始める前の摂取エネルギーが 13 日分だけのとき", () => {
    // 使い始めた日（昨日）の分は、端末が送った値でなく、nu-tori の食事の記録から数える
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays
        .slice(-14)
        .map((calendarDay) => ({ calendarDay, kcal: 500 }));
    });

    describe("昨日の食事の記録が無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "maintain",
          preUseEnergyIntakes,
        });
      });

      test("食べた量のある日が 14 日に足りず、逆算できないと返すこと", async () => {
        expect(await response.json()).toEqual({ canBackCalculate: false });
      });
    });

    describe("昨日に、推定の済んだ食事の記録があるとき", () => {
      let response: Response;
      beforeEach(async () => {
        mockCreateEstimationProviderOk();
        const photoId = generateRecordId();
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: {
                eatenAt: Date.parse(`${addDays(today, -1)}T03:00:00Z`),
                photos: [{ id: photoId }],
              },
            }),
          ],
        });
        await putMealPhoto(sessionToken, photoId);
        await runEstimationAlarm(accountId);
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "maintain",
          preUseEnergyIntakes,
        });
      });

      test("記録の食べた量を足して 14 日になり、逆算できると返すこと", async () => {
        expect(await response.json()).toEqual({ canBackCalculate: true });
      });
    });
  });

  describe("初めての目標で、体重記録が昨日の1つだけのとき", () => {
    // Mifflin-St Jeor: 10 × 70 + 6.25 × 170 − 5 × 40 + 5 = 1567.5。立ち仕事が多い（1.55）で 2,430 kcal
    const bodyData = {
      sex: "male",
      heightCentimeters: 170,
      ageYears: 40,
      activity: { type: "level", level: "standing" },
    };
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, [addDays(today, -1)], 70);
    });

    describe("身体データを添えずに、減量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", { direction: "lose" });
      });

      test("逆算できないことだけを返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { canBackCalculate: false },
        });
      });
    });

    describe("身体データを添えて、減量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", { direction: "lose", bodyData });
      });

      test("逆算できないことと、案を出せることを返すこと", async () => {
        expect(await response.json()).toEqual({
          canBackCalculate: false,
          canOfferLoseProposals: true,
        });
      });
    });

    describe("身体データを添えて、減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
          bodyData,
        });
      });

      test("式で出した推定消費カロリーと、最後の体重記録の日を返すこと", async () => {
        expect(await response.json()).toMatchObject({
          expenditureKcal: 2430,
          expenditureSource: "formula",
          startingWeightTrendKg: 70,
          lastWeightRecordedOn: addDays(today, -1),
        });
      });
    });

    describe("身体データを添えずに、減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        mockCaptureExceptionOk();
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
        });
      });

      test("身体データが無いという理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "body_data_missing" },
        });
      });
    });
  });

  describe("体重記録が1つも無いとき", () => {
    describe("減量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", { direction: "lose" });
      });

      test("逆算できないことだけを返すこと", async () => {
        expect(await response.json()).toEqual({ canBackCalculate: false });
      });
    });

    describe("維持の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        mockCaptureExceptionOk();
        response = await postGoalSetup(sessionToken, "proposals", { direction: "maintain" });
      });

      test("体重記録が無いという理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "weight_record_missing" },
        });
      });
    });
  });

  describe("今の目標があるとき", () => {
    // 逆算すれば 2,400 kcal になる記録と摂取エネルギーがあっても、今の推定（2,300 kcal）を使う
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 }));
      await seed(async (factory) => {
        await factory.goals.create({ startedOn: addDays(today, -10) });
        await factory.expenditureEstimates.create({
          effectiveOn: addDays(today, -10),
          expenditureKcal: 2300,
        });
      });
    });

    describe("減量の下見を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "lose",
          preUseEnergyIntakes,
        });
      });

      test("逆算できるかを答えず、案を出せるかだけを返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { canOfferLoseProposals: true },
        });
      });

      test("推定消費カロリーの推定を作らないこと", async () => {
        expect(
          await readRows(accountId, "SELECT expenditure_kcal FROM expenditure_estimates"),
        ).toEqual([{ expenditure_kcal: 2300 }]);
      });
    });

    describe("減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
          preUseEnergyIntakes,
        });
      });

      test("今の推定消費カロリーで出した案を、今日を開始の日にして返すこと", async () => {
        expect(await response.json()).toMatchObject({
          startedOn: today,
          expenditureKcal: 2300,
          expenditureSource: "current",
        });
      });
    });
  });

  describe("西へ移ったあとで、今の目標の開始の日が端末の今日より後のとき", () => {
    let currentGoalStartedOn: string;
    beforeEach(async () => {
      currentGoalStartedOn = addDays(today, 1);
      await recordDailyWeights(sessionToken, windowDays, 70);
      await seed(async (factory) => {
        await factory.goals.create({ startedOn: currentGoalStartedOn });
        await factory.expenditureEstimates.create({
          effectiveOn: currentGoalStartedOn,
          expenditureKcal: 2300,
        });
      });
    });

    describe("今の目標の開始の日から数えて 182 日めの期限で、減量の目標案を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        // 端末の今日から数えると 183 日めで、受け付ける期限の外になる
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn: addDays(currentGoalStartedOn, 181),
        });
      });

      test("開始の日が今の目標の開始の日になること", async () => {
        expect({ status: response.status, body: await response.json() }).toMatchObject({
          status: 200,
          body: { startedOn: currentGoalStartedOn },
        });
      });
    });

    describe("自分で決める目標体重を求めたとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn: addDays(currentGoalStartedOn, 181),
          targetWeightKg: 65,
        });
      });

      test("開始の日が今の目標の開始の日になること", async () => {
        expect(await response.json()).toMatchObject({ startedOn: currentGoalStartedOn });
      });
    });
  });

  describe("断る要求", () => {
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    // 断る理由のほかは、逆算できて案を出せる要求にする
    let preUseEnergyIntakes: { calendarDay: string; kcal: number }[];
    beforeEach(async () => {
      captureExceptionSpy = mockCaptureExceptionOk();
      await recordDailyWeights(sessionToken, windowDays, 70);
      preUseEnergyIntakes = windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 }));
    });

    describe("減量の目標案に期限が無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          preUseEnergyIntakes,
        });
      });

      test("形の誤りとして 400 で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 400,
          body: { code: "malformed_request" },
        });
      });

      test("誤っていた場所を Sentry に送ること", () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            name: "GoalSetupRequestMalformedError",
            issues: [{ path: "deadlineOn", code: "custom" }],
          }),
        );
      });
    });

    describe("期限が開始の日から数えて 27 日めのとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn: addDays(today, 26),
          preUseEnergyIntakes,
        });
      });

      test("期限が受け付ける幅の外という理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "deadline_out_of_range" },
        });
      });

      test("Sentry に送ること", () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            name: "GoalSetupRequestRejectedError",
            reason: "deadline_out_of_range",
          }),
        );
      });
    });

    describe("自分で決める目標体重の期限が、開始の日から数えて 183 日めのとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn: addDays(today, 182),
          targetWeightKg: 65,
          preUseEnergyIntakes,
        });
      });

      test("期限が受け付ける幅の外という理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "deadline_out_of_range" },
        });
      });
    });

    describe("身体データの身長が範囲の外のとき", () => {
      let response: Response;
      let logSpy: ReturnType<typeof vi.spyOn>;
      beforeEach(async () => {
        logSpy = vi.spyOn(console, "log");
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "lose",
          bodyData: {
            sex: "female",
            heightCentimeters: 99.5,
            ageYears: 40,
            activity: { type: "level", level: "sedentary" },
          },
        });
      });

      test("身体データが範囲の外という理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "body_data_out_of_range" },
        });
      });

      test("理由を Sentry に送ること", () => {
        expect(captureExceptionSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            name: "GoalSetupRequestRejectedError",
            reason: "body_data_out_of_range",
          }),
        );
      });

      test("Sentry に送るエラーに、身体データの値を載せないこと", () => {
        expect(
          captureExceptionSpy.mock.calls.map(
            ([error]) => `${String(error)} ${JSON.stringify(error)}`,
          ),
        ).toEqual([expect.not.stringContaining("99.5")]);
      });

      test("要求ごとのログを、今の要求と同じ形で、値を載せずに出すこと", () => {
        expect(logSpy.mock.calls).toEqual([
          [
            {
              requestId: expect.any(String),
              accountId,
              route: "POST /v1/goal-setup/preview",
              status: 422,
              appBuild: undefined,
              error: undefined,
              failedStage: undefined,
              durationMs: expect.any(Number),
            },
          ],
        ]);
      });
    });

    describe("タイムゾーンが IANA 名でないとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(sessionToken, "preview", {
          direction: "lose",
          timeZone: "+09:00",
        });
      });

      test("タイムゾーンが読めないという理由で断ること", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 422,
          body: { code: "invalid_time_zone" },
        });
      });
    });

    describe("セッションが無いとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await postGoalSetup(undefined, "preview", { direction: "lose" });
      });

      test("401 を返すこと", () => {
        expect(response.status).toBe(401);
      });
    });
  });

  describe("身体データと使い始める前の摂取エネルギーを添えて、3つの要求を出したあと", () => {
    let logSpy: ReturnType<typeof vi.spyOn>;
    let responses: Response[];
    beforeEach(async () => {
      await recordDailyWeights(sessionToken, [addDays(today, -1)], 70);
      logSpy = vi.spyOn(console, "log");
      // ほかの値に紛れない値にする
      const situation = {
        preUseEnergyIntakes: windowDays
          .slice(0, 5)
          .map((calendarDay) => ({ calendarDay, kcal: 2413.7 })),
        bodyData: {
          sex: "female",
          heightCentimeters: 171.3,
          ageYears: 113,
          activity: {
            type: "steps",
            dailySteps: windowDays.map((calendarDay) => ({ calendarDay, steps: 7654 })),
          },
        },
      };
      responses = [
        await postGoalSetup(sessionToken, "preview", { direction: "lose", ...situation }),
        await postGoalSetup(sessionToken, "proposals", {
          direction: "lose",
          deadlineOn,
          ...situation,
        }),
        await postGoalSetup(sessionToken, "custom-target-weight", {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 69,
          ...situation,
        }),
      ];
    });

    test("どの要求も答えること", () => {
      expect(responses.map(({ status }) => status)).toEqual([200, 200, 200]);
    });

    test("DB のどの表にも、身体データと摂取エネルギーの値が無いこと", async () => {
      expect(JSON.stringify(await readAllStoredRows(accountId))).not.toMatch(leftValuePattern);
    });

    test("ログに、身体データと摂取エネルギーの値が無いこと", () => {
      expect(JSON.stringify(logSpy.mock.calls)).not.toMatch(leftValuePattern);
    });

    test("目標・推定消費カロリー・1日の目安の表に、何も書かないこと", async () => {
      expect(
        await readRows(
          accountId,
          "SELECT id FROM goals UNION ALL SELECT id FROM expenditure_estimates UNION ALL SELECT id FROM daily_guides UNION ALL SELECT id FROM goal_decision_receipts",
        ),
      ).toEqual([]);
    });
  });
});

// 添えた摂取エネルギー（2413.7）と身長（171.3）、JSON の値として出る歩数（7654）と年齢（113）。ID や時刻の中の同じ並びは拾わない
const leftValuePattern = /2413\.7|171\.3|[:,[]"?(?:7654|113)"?[,}\]]/u;
