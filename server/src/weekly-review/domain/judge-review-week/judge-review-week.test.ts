import { beforeEach, describe, expect, test } from "vitest";
import { judgeReviewWeek, type ReviewWeekInputs, type ReviewWeekJudgement } from "./index";
import { daysFrom } from "../../testing/days-from";
import { computeWeightTrend } from "../../../weight-trend/domain/compute-weight-trend";
import { countDaysBetween } from "../../../domain/count-days-between";

// 見直す月曜は 2026-10-19。見直す入力の週は 2026-10-12（月）〜 2026-10-18（日）、その前の日曜は 2026-10-11
const reviewedMonday = "2026-10-19";

const weightsOn = (calendarDays: string[]) =>
  calendarDays.map((calendarDay) => ({ calendarDay, weightKg: 70 }));

const intakesOn = (calendarDays: string[], kcal = 2000) =>
  calendarDays.map((calendarDay) => ({ calendarDay, kcal }));

// 見直せる週。使い始めて 28 日、前の週から毎日 70 kg、入力の週の7日すべてに 2,000 kcal の食事
const reviewableInputs = (): ReviewWeekInputs => ({
  reviewedMonday,
  startedUsingOn: "2026-09-21",
  initialExpenditureSource: "formula",
  initialExpenditureKcal: 2000,
  dailyWeights: weightsOn(daysFrom("2026-10-05", 14)),
  recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7)),
});

const trendKgOn = (dailyWeights: ReviewWeekInputs["dailyWeights"], calendarDay: string): number => {
  const point = computeWeightTrend(dailyWeights).find((p) => p.calendarDay === calendarDay);
  if (point === undefined) {
    throw new Error(`${calendarDay} の体重の傾向が無い`);
  }
  return point.trendKg;
};

// 続けて見直す2週の体重。前の週（2026-10-05〜11）は毎日、続く2週は月・水・金だけ量り、1日に 0.1 kg ずつ減る
const irregularWeights = () =>
  [
    ...daysFrom("2026-10-05", 7),
    "2026-10-12",
    "2026-10-14",
    "2026-10-16",
    "2026-10-19",
    "2026-10-21",
    "2026-10-23",
  ].map((calendarDay) => ({
    calendarDay,
    weightKg: 70 - 0.1 * countDaysBetween("2026-10-05", calendarDay),
  }));

// 2026-10-19 と 2026-10-26 の見直しを続けて判定し、実際の変化と測った日数の和を返す。1回目の見直しは firstReviewSeesUntil までの体重記録を見る
const judgeTwoWeeks = (firstReviewSeesUntil: string) => {
  const first = judgeReviewWeek({
    ...reviewableInputs(),
    dailyWeights: irregularWeights().filter(
      ({ calendarDay }) => calendarDay <= firstReviewSeesUntil,
    ),
  });
  const second = judgeReviewWeek({
    ...reviewableInputs(),
    reviewedMonday: "2026-10-26",
    dailyWeights: irregularWeights(),
    recordedEnergyIntakes: intakesOn(daysFrom("2026-10-19", 7)),
  });
  if (first.type !== "reviewable" || second.type !== "reviewable") {
    throw new Error("見直せる週のはず");
  }
  return {
    actualWeightChangeKg: (first.actualWeightChangeKg + second.actualWeightChangeKg).toFixed(6),
    weightChangeDayCount: first.weightChangeDayCount + second.weightChangeDayCount,
  };
};

// 前の週の日曜（最後に量った日）から、後の週の金曜（最後に量った日）までの通しの変化
const wholeChangeOfTwoWeeks = () => ({
  actualWeightChangeKg: (
    trendKgOn(irregularWeights(), "2026-10-23") - trendKgOn(irregularWeights(), "2026-10-11")
  ).toFixed(6),
  weightChangeDayCount: 12,
});

describe("見直す週の判定", () => {
  describe("記録がそろった週のとき", () => {
    let judged: ReviewWeekJudgement;
    beforeEach(() => {
      judged = judgeReviewWeek(reviewableInputs());
    });

    test("見送らず、食べた量の平均・食事を記録した日数・実際の変化・日曜の体重の傾向を返すこと", () => {
      expect(judged).toEqual({
        type: "reviewable",
        averageEnergyIntakeKcal: 2000,
        recordedMealDayCount: 7,
        actualWeightChangeKg: 0,
        weightChangeDayCount: 7,
        sundayWeightTrendKg: 70,
      });
    });
  });

  describe("使い始めて7日未満のとき", () => {
    describe("見直す月曜の時点で使い始めて6日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({ ...reviewableInputs(), startedUsingOn: "2026-10-13" });
      });

      test("使い始めて7日未満で見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "within_first_week" });
      });
    });

    describe("見直す月曜の時点で使い始めて7日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({ ...reviewableInputs(), startedUsingOn: "2026-10-12" });
      });

      test("見送らないこと", () => {
        expect(judged.type).toBe("reviewable");
      });
    });

    describe("使い始める前の記録から初期値を逆算した人が、使い始めて1日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          startedUsingOn: "2026-10-18",
          initialExpenditureSource: "back_calculated",
        });
      });

      test("使い始めて7日未満を当てず、見送らないこと", () => {
        expect(judged.type).toBe("reviewable");
      });
    });
  });

  describe("体重記録について", () => {
    describe("入力の週に体重記録のある日が0日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: weightsOn(daysFrom("2026-10-05", 7)),
        });
      });

      test("体重が無いで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "no_weight" });
      });
    });

    describe("入力の週に体重記録のある日が日曜の1日だけのとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: weightsOn([...daysFrom("2026-10-05", 7), "2026-10-18"]),
        });
      });

      test("見送らないこと", () => {
        expect(judged.type).toBe("reviewable");
      });
    });

    describe("初めての体重記録が入力の週の月曜のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: [
            { calendarDay: "2026-10-12", weightKg: 70 },
            { calendarDay: "2026-10-18", weightKg: 70 },
          ],
        });
      });

      test("その前の日曜の代わりに月曜の体重の傾向を使い、月曜から日曜の 6 日で測ること", () => {
        expect(judged).toMatchObject({
          type: "reviewable",
          actualWeightChangeKg: 0,
          weightChangeDayCount: 6,
        });
      });
    });

    describe("初めての体重記録が入力の週の月曜の1日だけのとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: [{ calendarDay: "2026-10-12", weightKg: 70 }],
        });
      });

      test("変化を測る日が無いので、体重が無いで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "no_weight" });
      });
    });

    describe("前の週に体重記録が無いとき", () => {
      let dailyWeights: ReviewWeekInputs["dailyWeights"];
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        dailyWeights = [
          ...weightsOn(daysFrom("2026-09-28", 7)),
          ...daysFrom("2026-10-12", 7).map((calendarDay) => ({ calendarDay, weightKg: 69 })),
        ];
        judged = judgeReviewWeek({ ...reviewableInputs(), dailyWeights });
      });

      test("その前の日曜の体重の傾向（補った値）から、7 日で測ること", () => {
        expect(judged).toMatchObject({
          type: "reviewable",
          actualWeightChangeKg:
            trendKgOn(dailyWeights, "2026-10-18") - trendKgOn(dailyWeights, "2026-10-11"),
          weightChangeDayCount: 7,
        });
      });
    });

    describe("初めての体重記録が入力の週の火曜で、実際の変化を出せないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: weightsOn(daysFrom("2026-10-13", 6)),
        });
      });

      test("体重が無いで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "no_weight" });
      });
    });
  });

  describe("続けて見直した2週の体重の変化", () => {
    describe("1回目の見直しの時点で、その週の金曜より後の体重が無いとき", () => {
      let summed: ReturnType<typeof judgeTwoWeeks>;
      beforeEach(() => {
        summed = judgeTwoWeeks("2026-10-18");
      });

      test("2週の変化の和が、通しの変化と等しく、落ちる日が無いこと", () => {
        expect(summed).toEqual(wholeChangeOfTwoWeeks());
      });
    });

    describe("1回目の見直しの時点で、見直す月曜の体重があるとき", () => {
      let summed: ReturnType<typeof judgeTwoWeeks>;
      beforeEach(() => {
        summed = judgeTwoWeeks("2026-10-19");
      });

      test("2週の変化の和が、通しの変化と等しく、落ちる日が無いこと", () => {
        expect(summed).toEqual(wholeChangeOfTwoWeeks());
      });
    });
  });

  describe("食事の記録について", () => {
    describe("入力の週に食事を記録した日が3日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 3)),
        });
      });

      test("食事の記録が少ないで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "few_meal_records" });
      });
    });

    describe("入力の週に食事を記録した日が4日のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 4)),
        });
      });

      test("見送らず、4日の平均を返すこと", () => {
        expect(judged).toMatchObject({
          type: "reviewable",
          averageEnergyIntakeKcal: 2000,
          recordedMealDayCount: 4,
        });
      });
    });

    // 体重は毎日 70 kg で変わらないので、記録が意味する消費（観測）は、記録した日の平均そのもの
    describe("記録が意味する消費が、推定の始まり 2,000 kcal の 0.6 倍に満たないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7), 1199),
        });
      });

      test("記録の抜けとみなし、食事の記録が少ないで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "few_meal_records" });
      });
    });

    describe("記録が意味する消費が、推定の始まりのちょうど 0.6 倍のとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7), 1200),
        });
      });

      test("見送らないこと", () => {
        expect(judged).toMatchObject({ type: "reviewable", averageEnergyIntakeKcal: 1200 });
      });
    });

    describe("体重が減った分、記録が意味する消費が記録した量より多く、0.6 倍以上になるとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        // 入力の週に 70 kg から 69 kg へ下がる。記録した 1,000 kcal に、体重の傾向が減った分を足すと 0.6 倍を超える
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: [
            ...weightsOn(daysFrom("2026-10-05", 7)),
            ...daysFrom("2026-10-12", 7).map((calendarDay) => ({ calendarDay, weightKg: 69 })),
          ],
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7), 1000),
        });
      });

      test("見送らないこと", () => {
        expect(judged).toMatchObject({ type: "reviewable", averageEnergyIntakeKcal: 1000 });
      });
    });

    describe("推定の始まりが読めず、記録した量が少ないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          initialExpenditureKcal: undefined,
          recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7), 1000),
        });
      });

      test("比べる元が無いので、量では見送らないこと", () => {
        expect(judged).toMatchObject({ type: "reviewable", averageEnergyIntakeKcal: 1000 });
      });
    });

    describe("前の 28 日に食事を記録した日が7日以上あり、入力の週の4日のうち1日が中央値の半分に満たないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: [
            ...intakesOn(daysFrom("2026-09-28", 7)),
            ...intakesOn(daysFrom("2026-10-12", 3)),
            { calendarDay: "2026-10-15", kcal: 900 },
          ],
        });
      });

      test("その日を食事を記録した日に数えず、食事の記録が少ないで見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "few_meal_records" });
      });
    });

    describe("前の 28 日に食事を記録した日が7日以上あり、入力の週の5日のうち1日が中央値の半分に満たないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: [
            ...intakesOn(daysFrom("2026-09-28", 7)),
            ...intakesOn(daysFrom("2026-10-12", 4)),
            { calendarDay: "2026-10-16", kcal: 900 },
          ],
        });
      });

      test("その日を平均からも外すこと", () => {
        expect(judged).toMatchObject({
          type: "reviewable",
          averageEnergyIntakeKcal: 2000,
          recordedMealDayCount: 4,
        });
      });
    });

    describe("前の 28 日に食事を記録した日が6日で、入力の週の4日のうち1日が中央値の半分に満たないとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: [
            ...intakesOn(daysFrom("2026-09-28", 2)),
            ...intakesOn(daysFrom("2026-10-12", 3)),
            { calendarDay: "2026-10-15", kcal: 900 },
          ],
        });
      });

      test("その日を外さず、見送らないこと", () => {
        expect(judged).toMatchObject({
          type: "reviewable",
          averageEnergyIntakeKcal: 1725,
          recordedMealDayCount: 4,
        });
      });
    });

    describe("28 日より前の日の食事があるとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        // 28 日前より前の 1,000 kcal の日を中央値に入れれば、入力の週の 900 kcal は外れない
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          recordedEnergyIntakes: [
            ...intakesOn(daysFrom("2026-09-01", 20), 1000),
            ...intakesOn(daysFrom("2026-09-21", 7)),
            ...intakesOn(daysFrom("2026-10-12", 3)),
            { calendarDay: "2026-10-15", kcal: 900 },
          ],
        });
      });

      test("中央値に入れず、中央値の半分に満たない日を外して見送ること", () => {
        expect(judged).toEqual({ type: "deferred", reason: "few_meal_records" });
      });
    });
  });

  describe("理由が2つ以上当たるとき", () => {
    describe("使い始めて7日未満で、体重も食事の記録も無いとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          startedUsingOn: "2026-10-15",
          dailyWeights: [],
          recordedEnergyIntakes: [],
        });
      });

      test("使い始めて7日未満だけを残すこと", () => {
        expect(judged).toEqual({ type: "deferred", reason: "within_first_week" });
      });
    });

    describe("体重も食事の記録も無いとき", () => {
      let judged: ReviewWeekJudgement;
      beforeEach(() => {
        judged = judgeReviewWeek({
          ...reviewableInputs(),
          dailyWeights: [],
          recordedEnergyIntakes: [],
        });
      });

      test("体重が無いだけを残すこと", () => {
        expect(judged).toEqual({ type: "deferred", reason: "no_weight" });
      });
    });
  });
});
