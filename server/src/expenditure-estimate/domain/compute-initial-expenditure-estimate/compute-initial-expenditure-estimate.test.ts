import { beforeEach, describe, expect, test } from "vitest";
import { addDays } from "../../../domain/add-days";
import type { BodyData } from "../body-data";
import { computeInitialExpenditureEstimate } from "./index";

type Input = Parameters<typeof computeInitialExpenditureEstimate>[0];
type Estimate = ReturnType<typeof computeInitialExpenditureEstimate>;

// 今日は 2026-10-29。今日を除く直前の 28 日は 2026-10-01 から 2026-10-28
describe("推定消費カロリーの始まりの計算", () => {
  describe("逆算", () => {
    describe("食べた量のある日が 14 日、体重記録のある日が4日で最初と最後の差が 14 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        // 1日 2,000 kcal 食べ、日の代表値は 1日に 0.05 kg ずつ減る直線に載る
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("食べた量の平均から、7,700 kcal × 直線の傾きを引いた値を、逆算として返すこと", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value).toEqual({ kcal: 2385, source: "back_calculated" });
        });
      });
    });

    describe("食べた量のある日が 13 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 13, 2000),
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("体重記録のある日が3日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: [
              { calendarDay: "2026-10-01", weightKg: 70.0 },
              { calendarDay: "2026-10-08", weightKg: 69.65 },
              { calendarDay: "2026-10-15", weightKg: 69.3 },
            ],
          }),
        );
      });

      test("逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("体重記録のある日の最初と最後の差が 13 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: [
              { calendarDay: "2026-10-01", weightKg: 70.0 },
              { calendarDay: "2026-10-06", weightKg: 69.75 },
              { calendarDay: "2026-10-11", weightKg: 69.5 },
              { calendarDay: "2026-10-14", weightKg: 69.35 },
            ],
          }),
        );
      });

      test("逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("日の代表値が直線に載らないとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        // 最小二乗の傾きは -0.08 kg/日（最初と最後を結ぶと -1/15 kg/日）
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: [
              { calendarDay: "2026-10-01", weightKg: 70.0 },
              { calendarDay: "2026-10-06", weightKg: 70.0 },
              { calendarDay: "2026-10-11", weightKg: 69.0 },
              { calendarDay: "2026-10-16", weightKg: 69.0 },
            ],
          }),
        );
      });

      test("日の代表値に当てた直線の傾きを使うこと", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2616);
        });
      });
    });

    describe("食べた量のある日が、今日を入れて 14 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: [
              ...consecutiveDays("2026-10-01", 13, 2000),
              { calendarDay: "2026-10-29", kcal: 2000 },
            ],
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("今日を数えず、逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("食べた量のある日が、29 日前を入れて 14 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-09-30", 14, 2000),
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("29 日前を数えず、逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("体重記録のある日の最初と最後の差が、29 日前を入れて 14 日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: [
              { calendarDay: "2026-09-30", weightKg: 70.05 },
              { calendarDay: "2026-10-01", weightKg: 70.0 },
              { calendarDay: "2026-10-06", weightKg: 69.75 },
              { calendarDay: "2026-10-11", weightKg: 69.5 },
              { calendarDay: "2026-10-14", weightKg: 69.35 },
            ],
          }),
        );
      });

      test("29 日前を数えず、逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("食べた量のある日が 15 日で、1日が中央値の半分に満たないとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: [
              ...consecutiveDays("2026-10-01", 14, 2000),
              { calendarDay: "2026-10-15", kcal: 900 },
            ],
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("その日を食べた量の平均から外すこと", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2385);
        });
      });
    });

    describe("食べた量のある日が 14 日で、1日が中央値の半分に満たないとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: [
              ...consecutiveDays("2026-10-01", 13, 2000),
              { calendarDay: "2026-10-14", kcal: 900 },
            ],
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("その日を食べた量のある日に数えず、逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("使い始める前の7日に端末の摂取エネルギーが、使い始めてからの7日に記録があるとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startedUsingOn: "2026-10-08",
            deviceEnergyIntakes: consecutiveDays("2026-10-01", 7, 1800),
            recordedEnergyIntakes: consecutiveDays("2026-10-08", 7, 2200),
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("両方を食べた量にして逆算すること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value).toEqual({ kcal: 2385, source: "back_calculated" });
        });
      });
    });

    describe("端末の摂取エネルギーが、使い始めてからの日にもあるとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startedUsingOn: "2026-10-08",
            deviceEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("使い始めてからの日の端末の摂取エネルギーを数えず、逆算しないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("食べた量の平均から出した値が整数でないとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        // 食べた量の平均は 2,000.857…、逆算は 2,385.857…
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: [
              ...consecutiveDays("2026-10-01", 10, 2000),
              ...consecutiveDays("2026-10-11", 4, 2003),
            ],
            dailyWeights: weightsLosing50GramsPerDay,
          }),
        );
      });

      test("整数の kcal に丸めること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2386);
        });
      });
    });

    describe("逆算できて、範囲の外の身体データが届いているとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            recordedEnergyIntakes: consecutiveDays("2026-10-01", 14, 2000),
            dailyWeights: weightsLosing50GramsPerDay,
            startWeightTrendKg: 70,
            bodyData: { ...sedentaryMan, heightCentimeters: 1.72 },
          }),
        );
      });

      test("身体データを使わず、逆算を返すこと", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value).toEqual({ kcal: 2385, source: "back_calculated" });
        });
      });
    });
  });

  // 逆算できない（食べた量も体重記録も窓に無い）。体重 70 kg・身長 172 cm・36 歳の男の Mifflin-St Jeor は 1,600 kcal、女は 1,434 kcal
  describe("式", () => {
    describe("ほぼ座り仕事の男のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: sedentaryMan }),
        );
      });

      test("男の Mifflin-St Jeor に 1.4 を掛けた値を、式として返すこと", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value).toEqual({ kcal: 2240, source: "formula" });
        });
      });
    });

    describe("ほぼ座り仕事の女のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: { ...sedentaryMan, sex: "female" } }),
        );
      });

      test("女の Mifflin-St Jeor に 1.4 を掛け、整数の kcal に丸めること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value).toEqual({ kcal: 2008, source: "formula" });
        });
      });
    });

    describe("立ち仕事が多いとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startWeightTrendKg: 70,
            bodyData: { ...sedentaryMan, activity: { type: "level", level: "standing" } },
          }),
        );
      });

      test("1.55 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2480);
        });
      });
    });

    describe("よく動くとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startWeightTrendKg: 70,
            bodyData: { ...sedentaryMan, activity: { type: "level", level: "active" } },
          }),
        );
      });

      test("1.7 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2720);
        });
      });
    });

    describe("歩数の1日平均が 4,999 歩のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([4999]) }),
        );
      });

      test("1.4 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2240);
        });
      });
    });

    describe("歩数の1日平均が 5,000 歩のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([5000]) }),
        );
      });

      test("1.55 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2480);
        });
      });
    });

    describe("歩数の1日平均が 9,999 歩のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([9999]) }),
        );
      });

      test("1.55 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2480);
        });
      });
    });

    describe("歩数の1日平均が 10,000 歩のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([10_000]) }),
        );
      });

      test("1.7 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2720);
        });
      });
    });

    describe("0 歩の日が2日、10,000 歩の日が1日のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([0, 10_000, 0]) }),
        );
      });

      test("0 歩の日を平均から除き、1.7 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2720);
        });
      });
    });

    describe("今日と 29 日前に 20,000 歩、そのあいだの1日に 4,000 歩のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startWeightTrendKg: 70,
            bodyData: {
              ...sedentaryMan,
              activity: {
                type: "steps",
                dailySteps: [
                  { calendarDay: "2026-09-30", steps: 20_000 },
                  { calendarDay: "2026-10-10", steps: 4000 },
                  { calendarDay: "2026-10-29", steps: 20_000 },
                ],
              },
            },
          }),
        );
      });

      test("今日を除く直前の 28 日の歩数だけを平均し、1.4 を掛けること", () => {
        expect(estimate).toBeSuccess((value) => {
          expect(value.kcal).toBe(2240);
        });
      });
    });

    describe("歩数のある日が、0 歩の日だけのとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: manWalking([0, 0]) }),
        );
      });

      test("式に使う値が足りないと返すこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("身体データが無いとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(createInput({ startWeightTrendKg: 70 }));
      });

      test("式に使う値が足りないと返すこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("開始の日の体重の傾向が無いとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(createInput({ bodyData: sedentaryMan }));
      });

      test("式に使う値が足りないと返すこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error.name).toBe("FormulaInputsMissingError");
        });
      });
    });

    describe("身長が範囲の外のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({
            startWeightTrendKg: 70,
            bodyData: { ...sedentaryMan, heightCentimeters: 99.9 },
          }),
        );
      });

      test("身長を受け付けないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error).toMatchObject({
            name: "BodyDataOutOfRangeError",
            range: "heightCentimeters",
          });
        });
      });
    });

    describe("年齢が範囲の外のとき", () => {
      let estimate: Estimate;

      beforeEach(() => {
        estimate = computeInitialExpenditureEstimate(
          createInput({ startWeightTrendKg: 70, bodyData: { ...sedentaryMan, ageYears: 121 } }),
        );
      });

      test("年齢を受け付けないこと", () => {
        expect(estimate).toBeFailure((error) => {
          expect(error).toMatchObject({ name: "BodyDataOutOfRangeError", range: "ageYears" });
        });
      });
    });
  });
});

const createInput = (overrides: Partial<Input>): Input => ({
  today: "2026-10-29",
  startedUsingOn: "2026-09-01",
  deviceEnergyIntakes: [],
  recordedEnergyIntakes: [],
  dailyWeights: [],
  startWeightTrendKg: undefined,
  bodyData: undefined,
  ...overrides,
});

const consecutiveDays = (
  from: string,
  count: number,
  kcal: number,
): { calendarDay: string; kcal: number }[] =>
  Array.from({ length: count }, (_, offset) => ({ calendarDay: addDays(from, offset), kcal }));

// 70.0 kg から 1日に 0.05 kg ずつ減る直線の上の4日。最初と最後の差は 14 日
const weightsLosing50GramsPerDay = [
  { calendarDay: "2026-10-01", weightKg: 70.0 },
  { calendarDay: "2026-10-06", weightKg: 69.75 },
  { calendarDay: "2026-10-11", weightKg: 69.5 },
  { calendarDay: "2026-10-15", weightKg: 69.3 },
];

const sedentaryMan: BodyData = {
  sex: "male",
  heightCentimeters: 172,
  ageYears: 36,
  activity: { type: "level", level: "sedentary" },
};

// 窓の始まりの日から1日ずつの歩数
const manWalking = (steps: readonly number[]): BodyData => ({
  ...sedentaryMan,
  activity: {
    type: "steps",
    dailySteps: steps.map((count, offset) => ({
      calendarDay: addDays("2026-10-01", offset),
      steps: count,
    })),
  },
});
