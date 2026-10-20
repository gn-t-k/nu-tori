import { beforeEach, describe, expect, test } from "vitest";
import { judgeReviewWeek, type ReviewWeekInputs, type ReviewWeekJudgement } from "./index";
import { daysFrom } from "../../testing/days-from";

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
  dailyWeights: weightsOn(daysFrom("2026-10-05", 14)),
  recordedEnergyIntakes: intakesOn(daysFrom("2026-10-12", 7)),
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

      test("その前の日曜の代わりに月曜の体重の傾向を使い、見送らないこと", () => {
        expect(judged).toMatchObject({ type: "reviewable", actualWeightChangeKg: 0 });
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
