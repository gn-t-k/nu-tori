import { beforeEach, describe, expect, test } from "vitest";
import { computeReviewedExpenditure, type ReviewedExpenditureInputs } from "./index";

type Reviewed = ReturnType<typeof computeReviewedExpenditure>;

// 前の推定 2,400 kcal、平均 2,200 kcal、食事を記録した日 7 日、7 日で実際の変化 −0.4 kg の週。
// 予測した変化は（2,200 − 2,400）× 7 ÷ 7,700 = −0.1818 kg、ずれは 0.2182 kg で、観測 − 前の推定（ρ × ずれ ÷ 7）は 240 kcal
const inputs = (overrides: Partial<ReviewedExpenditureInputs> = {}): ReviewedExpenditureInputs => ({
  previousExpenditureKcal: 2400,
  averageEnergyIntakeKcal: 2200,
  recordedMealDayCount: 7,
  actualWeightChangeKg: -0.4,
  weightChangeDayCount: 7,
  initialExpenditureSource: "formula",
  previousWeeks: [],
  ...overrides,
});

const reviewedWeeks = (count: number, recordedMealDayCount = 7) =>
  Array.from({ length: count }, () => ({ type: "reviewed" as const, recordedMealDayCount }));

// 予測した変化は −0.1818 kg。実際の変化を変えて、観測 − 前の推定（ρ × ずれ ÷ 7）を決める
const actualChangeForObservationKcal = (observationMinusPreviousKcal: number) =>
  -0.1818181818 - (observationMinusPreviousKcal * 7) / 7700;

describe("見直した推定消費カロリー", () => {
  describe("推定の始まりが式で、最初の見直しのとき", () => {
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

    test("始まりの不確かさ 400 kcal から k を出し、推定を上げて、ずれの向きを正にすること", () => {
      // P⁻ = 400² + 40² = 161,600、k = 161,600 ÷（161,600 + 200²）= 0.8016、240 × k = 192.4 kcal
      expect({
        gain: reviewed.gain.toFixed(4),
        expenditureKcal: reviewed.expenditureKcal,
        deviationDirection: reviewed.deviationDirection,
      }).toEqual({ gain: "0.8016", expenditureKcal: 2592, deviationDirection: "positive" });
    });
  });

  describe("推定の始まりが逆算で、最初の見直しのとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(
        inputs({ initialExpenditureSource: "back_calculated" }),
      );
    });

    test("始まりの不確かさを 200 kcal にして、式より小さい k にすること", () => {
      // P⁻ = 200² + 40² = 41,600、k = 41,600 ÷ 81,600 = 0.5098
      expect(reviewed.gain.toFixed(4)).toBe("0.5098");
    });
  });

  describe("推定の始まりが読めないとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs({ initialExpenditureSource: undefined }));
    });

    test("式とみなすこと", () => {
      expect(reviewed.gain.toFixed(4)).toBe("0.8016");
    });
  });

  describe("前に1週見直したとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(1) }));
    });

    test("最初の見直しで不確かさが減った分、k を小さくすること", () => {
      // 最初の見直しの後の P = 161,600 × (1 − 0.8016) = 32,063、P⁻ = 32,063 + 40² = 33,663、k = 33,663 ÷ 73,663
      expect(reviewed.gain.toFixed(4)).toBe("0.4570");
    });
  });

  describe("前に4週見直したとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(4) }));
    });

    test("k をさらに小さくすること", () => {
      expect(reviewed.gain.toFixed(4)).toBe("0.2373");
    });
  });

  describe("前に20週見直したとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(20) }));
    });

    test("k を、本当の消費の動き（Q）と観測のぶれ（R）で決まる値に落ち着かせること", () => {
      expect(reviewed.gain.toFixed(4)).toBe("0.1811");
    });
  });

  describe("食事を記録した日が4日のとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(
        inputs({ recordedMealDayCount: 4, previousWeeks: reviewedWeeks(4) }),
      );
    });

    test("観測のぶれを 7 ÷ 4 倍とみなし、7日のときより小さい k にすること", () => {
      // 7日の週なら 0.2373
      expect(reviewed.gain.toFixed(4)).toBe("0.1510");
    });
  });

  describe("前の週を見送ったとき", () => {
    let afterDeferral: Reviewed;
    let withoutDeferral: Reviewed;
    beforeEach(() => {
      afterDeferral = computeReviewedExpenditure(
        inputs({ previousWeeks: [...reviewedWeeks(4), { type: "deferred" }] }),
      );
      withoutDeferral = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(4) }));
    });

    test("見送った週の分だけ不確かさが増え、k が大きくなること", () => {
      expect({
        afterDeferral: afterDeferral.gain.toFixed(4),
        withoutDeferral: withoutDeferral.gain.toFixed(4),
      }).toEqual({ afterDeferral: "0.2599", withoutDeferral: "0.2373" });
    });
  });

  describe("前に見直せた週の食事を記録した日が少なかったとき", () => {
    let fewMealDays: Reviewed;
    let fullMealDays: Reviewed;
    beforeEach(() => {
      fewMealDays = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(1, 4) }));
      fullMealDays = computeReviewedExpenditure(inputs({ previousWeeks: reviewedWeeks(1) }));
    });

    test("その週で不確かさがあまり減らず、次の週の k が大きいこと", () => {
      expect(fewMealDays.gain).toBeGreaterThan(fullMealDays.gain);
    });
  });

  describe("k がいちばん大きい、推定の始まりが式の最初の見直しのとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(inputs());
    });

    test("前の推定と観測（2,400 + 240 kcal）のあいだに収め、観測を越えて動かさないこと", () => {
      expect(reviewed.expenditureKcal > 2400 && reviewed.expenditureKcal < 2640).toBe(true);
    });
  });

  describe("1回の動きの上限について", () => {
    describe("推定の始まりが式の最初の見直しで、観測が前の推定より 500 kcal 低いとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({ actualWeightChangeKg: actualChangeForObservationKcal(-500) }),
        );
      });

      test("k は 0.8016 のままで、動きを −250 kcal で止め、上限に当たったとすること", () => {
        // −500 × 0.8016 = −400.8 kcal を −250 kcal にする
        expect({
          gain: reviewed.gain.toFixed(4),
          expenditureKcal: reviewed.expenditureKcal,
          hitAdjustmentLimit: reviewed.hitAdjustmentLimit,
        }).toEqual({ gain: "0.8016", expenditureKcal: 2150, hitAdjustmentLimit: true });
      });
    });

    describe("推定の始まりが式の最初の見直しで、観測が前の推定より 300 kcal 高いとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({ actualWeightChangeKg: actualChangeForObservationKcal(300) }),
        );
      });

      test("上限に当たらず、約 +240 kcal 動かすこと", () => {
        // 300 × 0.8016 = 240.5 kcal
        expect({
          expenditureKcal: reviewed.expenditureKcal,
          hitAdjustmentLimit: reviewed.hitAdjustmentLimit,
        }).toEqual({ expenditureKcal: 2640, hitAdjustmentLimit: false });
      });
    });

    describe("推定の始まりが逆算の最初の見直しで、観測が前の推定より 400 kcal 低いとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            initialExpenditureSource: "back_calculated",
            actualWeightChangeKg: actualChangeForObservationKcal(-400),
          }),
        );
      });

      test("上限に当たらず、約 −200 kcal 動かすこと", () => {
        // −400 × 0.5098 = −203.9 kcal
        expect({
          expenditureKcal: reviewed.expenditureKcal,
          hitAdjustmentLimit: reviewed.hitAdjustmentLimit,
        }).toEqual({ expenditureKcal: 2196, hitAdjustmentLimit: false });
      });
    });

    describe("前の2回の見直しで上限に当たったあとの3回目のとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        // 上限で動きを止めても、不確かさは止めないときと同じに縮める（見直した週の並びだけからたどり直す）
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: reviewedWeeks(2),
            actualWeightChangeKg: actualChangeForObservationKcal(-1000),
          }),
        );
      });

      test("k を 0.3320 まで小さくし、動きを −250 kcal で止めること", () => {
        // −1,000 × 0.3320 = −332 kcal を −250 kcal にする
        expect({
          gain: reviewed.gain.toFixed(4),
          expenditureKcal: reviewed.expenditureKcal,
        }).toEqual({ gain: "0.3320", expenditureKcal: 2150 });
      });
    });

    describe("推定の始まりが式で、最初の週を見送った次の見直しのとき", () => {
      let reviewed: Reviewed;
      beforeEach(() => {
        reviewed = computeReviewedExpenditure(
          inputs({
            previousWeeks: [{ type: "deferred" }],
            actualWeightChangeKg: actualChangeForObservationKcal(-500),
          }),
        );
      });

      test("見送った分 k が大きくなっても、動きは −250 kcal までにすること", () => {
        // P⁻ = 400² + 2 × 40² = 163,200、k = 163,200 ÷ 203,200 = 0.8031
        expect({
          gain: reviewed.gain.toFixed(4),
          expenditureKcal: reviewed.expenditureKcal,
        }).toEqual({ gain: "0.8031", expenditureKcal: 2150 });
      });
    });
  });

  describe("予測より体重が減らなかったとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      // 予測した変化 −0.1818 kg、実際の変化 0 kg で、ずれは −0.1818 kg。観測 − 前の推定は −200 kcal、× 0.2373 = −47.5 kcal
      reviewed = computeReviewedExpenditure(
        inputs({ actualWeightChangeKg: 0, previousWeeks: reviewedWeeks(4) }),
      );
    });

    test("推定を下げ、ずれの向きを負にすること", () => {
      expect(reviewed).toMatchObject({ expenditureKcal: 2353, deviationDirection: "negative" });
    });
  });

  describe("予測と実際の変化が同じとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(
        inputs({ averageEnergyIntakeKcal: 2400, actualWeightChangeKg: 0 }),
      );
    });

    test("推定を変えず、ずれの向きを 0 にすること", () => {
      expect(reviewed).toMatchObject({ expenditureKcal: 2400, deviationDirection: "zero" });
    });
  });

  describe("実際の変化を 9 日で測ったとき", () => {
    let reviewed: Reviewed;
    beforeEach(() => {
      reviewed = computeReviewedExpenditure(
        inputs({ weightChangeDayCount: 9, previousWeeks: reviewedWeeks(4) }),
      );
    });

    test("予測した変化を 9 日分で出すこと", () => {
      // （2,200 − 2,400）× 9 ÷ 7,700 = −0.2338 kg、ずれは 0.1662 kg
      expect({
        predicted: reviewed.predictedWeightChangeKg.toFixed(4),
        deviation: reviewed.deviationKg.toFixed(4),
      }).toEqual({ predicted: "-0.2338", deviation: "0.1662" });
    });

    test("ずれを 9 日で割って1日あたりにしてから推定を動かすこと", () => {
      // 7,700 × 0.1662 ÷ 9 = 142.2 kcal、× 0.2373 = 33.7 kcal
      expect(reviewed.expenditureKcal).toBe(2434);
    });
  });
});
