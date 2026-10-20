import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { seedWeightChangeGoal } from "./testing/seed-weight-change-goal";
import { writeGoalProgressInAccount } from "./testing/write-goal-progress-in-account";

type Seed = Parameters<typeof writeGoalProgressInAccount>[0];
type Writes = Parameters<typeof writeGoalProgressInAccount>[1];

describe("期限の日の確定を書く口", () => {
  let seed: Seed;
  let writes: Writes;

  describe("減量・増量の目標に確定を書くとき", () => {
    beforeEach(() => {
      seed = seedWeightChangeGoal;
      writes = [{ type: "deadline_confirmation", deadlineWeightTrendKg: 69.8 }];
    });

    test("確定を書き、目標の変更を足すこと", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toEqual({
        errors: [undefined],
        achievedOn: [],
        deadlineWeightTrendKg: [69.8],
        changedRecordTypes: ["goal"],
        foreignKeyViolations: [],
      });
    });
  });

  describe("同じ目標に確定を2回書くとき", () => {
    beforeEach(() => {
      seed = seedWeightChangeGoal;
      writes = [
        { type: "deadline_confirmation", deadlineWeightTrendKg: 69.8 },
        { type: "deadline_confirmation", deadlineWeightTrendKg: 69.5 },
      ];
    });

    test("2回目を書かずに投げること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: [undefined, "期限の日を確定した目標を、もう一度確定しようとした"],
        deadlineWeightTrendKg: [69.8],
      });
    });
  });

  describe("維持の目標に書くとき", () => {
    beforeEach(() => {
      seed = async (factory) => (await factory.goals.create({ id: generateRecordId() })).id;
      writes = [{ type: "deadline_confirmation", deadlineWeightTrendKg: 70 }];
    });

    test("書かずに投げること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: ["期限の日を確定する目標が、減量・増量の目標ではない"],
        deadlineWeightTrendKg: [],
      });
    });
  });
});
