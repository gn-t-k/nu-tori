import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../../domain/record-id";
import { seedWeightChangeGoal } from "./testing/seed-weight-change-goal";
import { writeGoalProgressInAccount } from "./testing/write-goal-progress-in-account";

type Seed = Parameters<typeof writeGoalProgressInAccount>[0];
type Writes = Parameters<typeof writeGoalProgressInAccount>[1];

describe("達成を書く口", () => {
  let seed: Seed;
  let writes: Writes;

  describe("減量・増量の目標に達成を書くとき", () => {
    beforeEach(() => {
      seed = seedWeightChangeGoal;
      writes = [{ type: "achievement", achievedOn: "2026-11-20" }];
    });

    test("達成を書き、目標の変更を足すこと", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toEqual({
        errors: [undefined],
        achievedOn: ["2026-11-20"],
        deadlineWeightTrendKg: [],
        changedRecordTypes: ["goal"],
        foreignKeyViolations: [],
      });
    });
  });

  describe("同じ目標に達成を2回書くとき", () => {
    beforeEach(() => {
      seed = seedWeightChangeGoal;
      writes = [
        { type: "achievement", achievedOn: "2026-11-20" },
        { type: "achievement", achievedOn: "2026-11-21" },
      ];
    });

    test("2回目を書かずに投げること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: [undefined, "達成した目標に、達成をもう一度書こうとした"],
        achievedOn: ["2026-11-20"],
      });
    });
  });

  describe("期限の日の結果を確定したあとに書くとき", () => {
    beforeEach(() => {
      seed = seedWeightChangeGoal;
      writes = [
        { type: "deadline_confirmation", deadlineWeightTrendKg: 70.4 },
        { type: "achievement", achievedOn: "2026-11-30" },
        { type: "achievement", achievedOn: "2026-12-01" },
      ];
    });

    test("期限の日以前の日を達成にせず、期限の日より後の日だけを達成にすること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: [
          undefined,
          "期限の日の結果を確定したあとに、期限の日以前の日を達成した日にしようとした",
          undefined,
        ],
        achievedOn: ["2026-12-01"],
      });
    });
  });

  describe("閉じた目標に書くとき", () => {
    beforeEach(() => {
      seed = async (factory) => {
        const goalId = await seedWeightChangeGoal(factory);
        const next = await factory.goals.create({ startedOn: "2026-11-10" });
        await factory.goalClosures.create({ goalId, nextGoalId: next.id });
        return goalId;
      };
      writes = [{ type: "achievement", achievedOn: "2026-11-05" }];
    });

    test("書かずに投げること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: ["閉じた目標に達成を書こうとした"],
        achievedOn: [],
      });
    });
  });

  describe("維持の目標に書くとき", () => {
    beforeEach(() => {
      seed = async (factory) => (await factory.goals.create({ id: generateRecordId() })).id;
      writes = [{ type: "achievement", achievedOn: "2026-11-05" }];
    });

    test("書かずに投げること", async () => {
      expect(await writeGoalProgressInAccount(seed, writes)).toMatchObject({
        errors: ["達成を書く目標が、減量・増量の目標ではない"],
        achievedOn: [],
      });
    });
  });
});
