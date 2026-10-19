import { describe, expect, test } from "vitest";
import testCases from "../../../../../shared/pace.test-cases.json";
import { weightChangeDirections } from "../weight-change-direction";
import { computePace } from "./index";

describe("ペース", () => {
  test.for(testCases)(
    "$name とき、$expected.status を返すこと",
    ({ judgedOn, weightTrend, weightRecordDays, goal, achievedOn, expected }) => {
      // JSON の向きは文字列に広がるので、減量・増量の向きに絞り直す
      const direction = weightChangeDirections.find((candidate) => candidate === goal.direction);
      expect(
        computePace({
          judgedOn,
          weightTrend,
          weightRecordDays,
          goal:
            direction === undefined || goal.deadlineOn === null
              ? { direction: "maintain", targetWeightKg: goal.targetWeightKg }
              : {
                  direction,
                  startedOn: goal.startedOn,
                  deadlineOn: goal.deadlineOn,
                  targetWeightKg: goal.targetWeightKg,
                },
          achievedOn: achievedOn ?? undefined,
        }),
      ).toEqual(expected);
    },
  );
});
