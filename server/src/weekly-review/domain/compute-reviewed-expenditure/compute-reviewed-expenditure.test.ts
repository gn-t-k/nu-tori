import { beforeEach, describe, expect, test } from "vitest";
import { computeReviewedExpenditure, type ReviewedExpenditureInputs } from "./index";

type Reviewed = ReturnType<typeof computeReviewedExpenditure>;

// 前の推定 2,400 kcal、平均 2,200 kcal、食事を記録した日 7 日、実際の変化 −0.4 kg の週。
// 予測した変化は（2,200 − 2,400）× 7 ÷ 7,700 = −0.1818 kg、ずれは 0.2182 kg で、
// ρ × ずれ ÷ 7 は 240 kcal
const inputs = (overrides: Partial<ReviewedExpenditureInputs> = {}): ReviewedExpenditureInputs => ({
  previousExpenditureKcal: 2400,
  averageEnergyIntakeKcal: 2200,
  recordedMealDayCount: 7,
  actualWeightChangeKg: -0.4,
  previousWeeks: [],
  ...overrides,
});

describe("見直した推定消費カロリー", () => {
  describe("最初の見直しで、予測より体重が減ったとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs());
    });

    test("予測した変化とずれを返すこと", () => {
      expect({
        predicted: reviewed.predictedWeightChangeKg.toFixed(4),
        deviation: reviewed.deviationKg.toFixed(4),
      }).toEqual({ predicted: "-0.1818", deviation: "0.2182" });
    });

    test("続いた週の数を 0 にして k を 0.25 にし、推定を 60 kcal 上げて、ずれの向きを正にすること", () => {
      expect({
        expenditureKcal: reviewed.expenditureKcal,
        deviationDirection: reviewed.deviationDirection,
      }).toEqual({ expenditureKcal: 2460, deviationDirection: "positive" });
    });
  });

  describe("予測より体重が減らなかったとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      // 予測した変化 −0.1818 kg、実際の変化 0 kg で、ずれは −0.1818 kg。0.25 × 7,700 × ずれ ÷ 7 = −50 kcal
      reviewed = computeReviewedExpenditure(inputs({ actualWeightChangeKg: 0 }));
    });

    test("推定を下げ、ずれの向きを負にすること", () => {
      expect(reviewed).toMatchObject({ expenditureKcal: 2350, deviationDirection: "negative" });
    });
  });

  describe("予測と実際の変化が同じとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(
        inputs({
          averageEnergyIntakeKcal: 2400,
          actualWeightChangeKg: 0,
          previousWeeks: [{ type: "reviewed", deviationDirection: "zero" }],
        }),
      );
    });

    test("推定を変えず、ずれの向きを 0 にすること", () => {
      expect(reviewed).toMatchObject({ expenditureKcal: 2400, deviationDirection: "zero" });
    });
  });

  describe("食事を記録した日が4日のとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs({ recordedMealDayCount: 4 }));
    });

    test("k を 0.25 × 4 / 7 にすること", () => {
      // 240 kcal × 4 / 7 = 137.1 kcal × 0.25 = 34.3 kcal
      expect(reviewed.expenditureKcal).toBe(2434);
    });
  });

  describe("続いた週の数", () => {
    describe("前に見直せた週が同じ向きのとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({ previousWeeks: [{ type: "reviewed", deviationDirection: "positive" }] }),
        );
      });

      test("1つ増やして k を 0.5 にすること", () => {
        expect(reviewed.expenditureKcal).toBe(2520);
      });
    });

    describe("前の週を見送り、その前に見直せた週が同じ向きのとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: [
              { type: "deferred" },
              { type: "reviewed", deviationDirection: "positive" },
            ],
          }),
        );
      });

      test("見送った週を飛ばして数えること", () => {
        expect(reviewed.expenditureKcal).toBe(2520);
      });
    });

    describe("前に見直せた週と向きが変わったとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: [
              { type: "reviewed", deviationDirection: "negative" },
              { type: "reviewed", deviationDirection: "positive" },
            ],
          }),
        );
      });

      test("0 に戻すこと", () => {
        expect(reviewed.expenditureKcal).toBe(2460);
      });
    });

    describe("前に見直せた週のずれが 0 のとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: [
              { type: "reviewed", deviationDirection: "zero" },
              { type: "reviewed", deviationDirection: "positive" },
            ],
          }),
        );
      });

      test("0 に戻すこと", () => {
        expect(reviewed.expenditureKcal).toBe(2460);
      });
    });

    describe("同じ向きの週が3つ続いたとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: [
              { type: "reviewed", deviationDirection: "positive" },
              { type: "reviewed", deviationDirection: "positive" },
              { type: "reviewed", deviationDirection: "positive" },
            ],
          }),
        );
      });

      test("k を上限の 0.75 で止めること", () => {
        // 続いた週の数は 3 で、0.25 ×（1 + 3）= 1.0 になるところを 0.75 で止める
        expect(reviewed.expenditureKcal).toBe(2580);
      });
    });
  });
});
