import { R } from "@praha/byethrow";
import { beforeEach, describe, expect, test } from "vitest";
import type { ComputedDailyGuide } from "../../../daily-guide/domain/computed-daily-guide";
import { addDays } from "../../../domain/add-days";
import type { CompleteGoalSetupBasis } from "../goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import { proposalPaces, type ProposalPace } from "../proposal-pace";
import type { WeightChangeDirection } from "../weight-change-direction";
import { assessGoalDecision, computeGoalOffer } from "./index";

// 前提にする成功の値。失敗なら投げる
const succeeded = <T>(result: R.Result<T, GoalSetupRequestRejectedError>): T => {
  if (R.isFailure(result)) {
    throw new Error("見せる値か判定が、失敗で返った", { cause: result.error });
  }
  return result.value;
};

// 1日の目安が下限に当たる人・当たらない人、軽い人・重い人、受け付けるいちばん短い期限・長い期限と、その間の端数の日数。
// 期限の日は、開始の日から両端を含めて数えた日数で置く
const createBasisCases = (
  startedOn: string,
): { basis: CompleteGoalSetupBasis; direction: WeightChangeDirection; deadlineOn: string }[] =>
  [1300, 1500, 1830, 2250, 2875, 3600].flatMap((kcal) =>
    [41.27, 52.05, 60, 72.4, 88.66, 131.93].flatMap((trendKg) =>
      [28, 29, 55, 84, 121, 182].flatMap((days) =>
        (["lose", "gain"] as const).map((direction) => ({
          basis: {
            startedOn,
            currentGoal: undefined,
            startingWeightTrend: { trendKg, lastWeightRecordedOn: startedOn },
            expenditure: { source: "formula", kcal },
          },
          direction,
          deadlineOn: addDays(startedOn, days - 1),
        })),
      ),
    ),
  );

describe("目標を決めるかの判定", () => {
  describe("目標案に出した値で決めるとき", () => {
    let startedOn: string;
    let offeredProposals: {
      basis: CompleteGoalSetupBasis;
      direction: WeightChangeDirection;
      deadlineOn: string;
      pace: ProposalPace;
      targetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
    }[];

    beforeEach(() => {
      startedOn = "2026-10-27";
      offeredProposals = createBasisCases(startedOn).flatMap(({ basis, direction, deadlineOn }) => {
        const { plan } = succeeded(computeGoalOffer(basis, { direction, deadlineOn }));
        if (plan.direction === "maintain") {
          throw new Error("減量・増量の見せる値が返らない");
        }
        return plan.proposals.flatMap((proposal) =>
          proposal.status === "offered" ? [{ basis, direction, deadlineOn, ...proposal }] : [],
        );
      });
      // 下の性質が、出した案の無いまま通らないように
      if (offeredProposals.length === 0) {
        throw new Error("出した案が無い");
      }
    });

    test("どの計算の元とどの案でも決まること", () => {
      expect(
        offeredProposals.filter(
          ({ basis, direction, deadlineOn, pace, targetWeightKg, dailyGuide }) =>
            succeeded(
              assessGoalDecision(basis, {
                startedOn,
                choice: { type: "proposal", direction, deadlineOn, pace },
                shown: { targetWeightKg, dailyGuide },
              }),
            ).status !== "accepted",
        ),
      ).toStrictEqual([]);
    });
  });

  describe("自分で決めた目標体重を受け付けたときの値で決めるとき", () => {
    let startedOn: string;
    let acceptedTargetWeights: {
      basis: CompleteGoalSetupBasis;
      direction: WeightChangeDirection;
      deadlineOn: string;
      enteredTargetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
    }[];

    beforeEach(() => {
      startedOn = "2026-10-27";
      acceptedTargetWeights = createBasisCases(startedOn).flatMap(
        ({ basis, direction, deadlineOn }) => {
          const { plan } = succeeded(computeGoalOffer(basis, { direction, deadlineOn }));
          if (plan.direction === "maintain") {
            throw new Error("減量・増量の見せる値が返らない");
          }
          // 体重の傾向の前後 25kg を、0.1kg 単位に乗らない刻みで入れる
          return Array.from(
            { length: 200 },
            (_, index) => basis.startingWeightTrend.trendKg - 25 + index * 0.253,
          ).flatMap((enteredTargetWeightKg) => {
            const evaluation = plan.evaluateCustomTargetWeight(enteredTargetWeightKg);
            return evaluation.status === "accepted"
              ? [
                  {
                    basis,
                    direction,
                    deadlineOn,
                    enteredTargetWeightKg,
                    dailyGuide: evaluation.dailyGuide,
                  },
                ]
              : [];
          });
        },
      );
      // 下の性質が、受け付けた目標体重の無いまま通らないように
      if (acceptedTargetWeights.length === 0) {
        throw new Error("受け付けた目標体重が無い");
      }
    });

    test("どの計算の元とどの目標体重でも決まること", () => {
      expect(
        acceptedTargetWeights.filter(
          ({ basis, direction, deadlineOn, enteredTargetWeightKg, dailyGuide }) =>
            succeeded(
              assessGoalDecision(basis, {
                startedOn,
                choice: {
                  type: "custom",
                  direction,
                  deadlineOn,
                  targetWeightKg: enteredTargetWeightKg,
                },
                shown: { targetWeightKg: enteredTargetWeightKg, dailyGuide },
              }),
            ).status !== "accepted",
        ),
      ).toStrictEqual([]);
    });
  });

  describe("維持の見せる値で決めるとき", () => {
    let startedOn: string;
    let maintenanceOffers: {
      basis: CompleteGoalSetupBasis;
      targetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
    }[];

    beforeEach(() => {
      startedOn = "2026-10-27";
      maintenanceOffers = createBasisCases(startedOn).map(({ basis }) => {
        const { plan } = succeeded(computeGoalOffer(basis, { direction: "maintain" }));
        if (plan.direction !== "maintain") {
          throw new Error("維持の見せる値が返らない");
        }
        return { basis, ...plan.maintenance };
      });
    });

    test("どの計算の元でも決まること", () => {
      expect(
        maintenanceOffers.filter(
          ({ basis, targetWeightKg, dailyGuide }) =>
            succeeded(
              assessGoalDecision(basis, {
                startedOn,
                choice: { type: "maintain" },
                shown: { targetWeightKg, dailyGuide },
              }),
            ).status !== "accepted",
        ),
      ).toStrictEqual([]);
    });
  });

  describe("目標案と目標体重が 0.1kg 違う値を見せていたとき", () => {
    let startedOn: string;
    let basis: CompleteGoalSetupBasis;
    let deadlineOn: string;

    beforeEach(() => {
      startedOn = "2026-10-27";
      // 体重の傾向 72.4kg・推定消費カロリー 2,250kcal・84 日の標準の案は 68.1kg・1,850kcal（compute-goal-proposals のテスト）
      basis = {
        startedOn,
        currentGoal: undefined,
        startingWeightTrend: { trendKg: 72.4, lastWeightRecordedOn: startedOn },
        expenditure: { source: "formula", kcal: 2250 },
      };
      deadlineOn = addDays(startedOn, 83);
    });

    test("決めずに、新しい案を返すこと", () => {
      expect(
        assessGoalDecision(basis, {
          startedOn,
          choice: { type: "proposal", direction: "lose", deadlineOn, pace: "standard" },
          shown: {
            targetWeightKg: 68.2,
            dailyGuide: { energyKcal: 1850, proteinG: 110, fatG: 50, carbohydrateG: 240 },
          },
        }),
      ).toBeSuccess((assessment) =>
        expect(assessment).toMatchObject({
          status: "recalculated",
          proposals: { plan: { proposals: proposalPaces.map((pace) => ({ pace })) } },
        }),
      );
    });
  });
});
