import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { createRecordChangeWriter } from "../../durable-object/create-record-change-writer";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import { writeGoalAchievement } from "../domain/write-goal-achievement";
import { writeGoalDeadlineConfirmation } from "../domain/write-goal-deadline-confirmation";

type Factory = ReturnType<typeof durableObjectFactory>;
type Write =
  | { type: "achievement"; achievedOn: string }
  | { type: "deadline_confirmation"; deadlineWeightTrendKg: number };

const judgedAt = new Date("2026-12-01T03:00:00Z");

// 新しいアカウントに目標の行を置き、達成と確定を順に書く。投げたエラーの文（投げなければ undefined）と、書いたあとの行を返す
const writeInAccount = (
  seed: (factory: Factory) => Promise<RecordId>,
  writes: Write[],
): Promise<{
  errors: (string | undefined)[];
  achievedOn: unknown[];
  deadlineWeightTrendKg: unknown[];
  changedRecordTypes: unknown[];
  foreignKeyViolations: unknown[];
}> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    const goalId = await seed(
      durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })),
    );
    const { goal } = createRecordKindStores(state.storage);
    const errors = writes.map((write) => {
      try {
        createRecordChangeWriter(state.storage)(({ addChange }) =>
          write.type === "achievement"
            ? writeGoalAchievement(goal, addChange, {
                goalId,
                achievement: { achievedOn: write.achievedOn, judgedAt, timeZone: "Asia/Tokyo" },
              })
            : writeGoalDeadlineConfirmation(goal, addChange, {
                goalId,
                confirmation: {
                  deadlineWeightTrendKg: write.deadlineWeightTrendKg,
                  confirmedAt: judgedAt,
                  timeZone: "Asia/Tokyo",
                },
              }),
        );
        return undefined;
      } catch (thrown) {
        return thrown instanceof Error ? thrown.message : String(thrown);
      }
    });
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    return {
      errors,
      achievedOn: read("SELECT achieved_on FROM goal_achievements").map(
        (row) => row["achieved_on"],
      ),
      deadlineWeightTrendKg: read(
        "SELECT deadline_weight_trend_kg FROM goal_deadline_confirmations",
      ).map((row) => row["deadline_weight_trend_kg"]),
      changedRecordTypes: read("SELECT record_type FROM record_changes ORDER BY sequence").map(
        (row) => row["record_type"],
      ),
      foreignKeyViolations: read("PRAGMA foreign_key_check"),
    };
  });

// 期限が 2026-11-30 の減量の目標
const seedWeightChangeGoal = async (factory: Factory): Promise<RecordId> => {
  const goal = await factory.goals.create({ startingWeightTrendKg: 74, targetWeightKg: 70 });
  await factory.weightChangeGoals.create({ goalId: goal.id, deadlineOn: "2026-11-30" });
  return goal.id;
};

describe("目標の経過を書く口", () => {
  test("減量・増量の目標に達成と確定を1回ずつ書き、どちらも目標の変更を足すこと", async () => {
    expect(
      await writeInAccount(seedWeightChangeGoal, [
        { type: "achievement", achievedOn: "2026-11-20" },
        { type: "deadline_confirmation", deadlineWeightTrendKg: 69.8 },
      ]),
    ).toEqual({
      errors: [undefined, undefined],
      achievedOn: ["2026-11-20"],
      deadlineWeightTrendKg: [69.8],
      changedRecordTypes: ["goal", "goal"],
      foreignKeyViolations: [],
    });
  });

  test("同じ目標に達成も確定も2回は書かないこと", async () => {
    const written = await writeInAccount(seedWeightChangeGoal, [
      { type: "achievement", achievedOn: "2026-11-20" },
      { type: "achievement", achievedOn: "2026-11-21" },
      { type: "deadline_confirmation", deadlineWeightTrendKg: 69.8 },
      { type: "deadline_confirmation", deadlineWeightTrendKg: 69.5 },
    ]);
    expect({
      errors: written.errors,
      achievedOn: written.achievedOn,
      deadlineWeightTrendKg: written.deadlineWeightTrendKg,
    }).toEqual({
      errors: [
        undefined,
        "達成した目標に、達成をもう一度書こうとした",
        undefined,
        "期限の日を確定した目標を、もう一度確定しようとした",
      ],
      achievedOn: ["2026-11-20"],
      deadlineWeightTrendKg: [69.8],
    });
  });

  test("確定のあとは、期限の日以前の日を達成にせず、期限の日より後の日だけを達成にすること", async () => {
    const written = await writeInAccount(seedWeightChangeGoal, [
      { type: "deadline_confirmation", deadlineWeightTrendKg: 70.4 },
      { type: "achievement", achievedOn: "2026-11-30" },
      { type: "achievement", achievedOn: "2026-12-01" },
    ]);
    expect({ errors: written.errors, achievedOn: written.achievedOn }).toEqual({
      errors: [
        undefined,
        "期限の日の結果を確定したあとに、期限の日以前の日を達成した日にしようとした",
        undefined,
      ],
      achievedOn: ["2026-12-01"],
    });
  });

  test("閉じた目標には達成を書かないこと", async () => {
    const written = await writeInAccount(
      async (factory) => {
        const goalId = await seedWeightChangeGoal(factory);
        const next = await factory.goals.create({ startedOn: "2026-11-10" });
        await factory.goalClosures.create({ goalId, nextGoalId: next.id });
        return goalId;
      },
      [{ type: "achievement", achievedOn: "2026-11-05" }],
    );
    expect(written.errors).toEqual(["閉じた目標に達成を書こうとした"]);
  });

  test("維持の目標には達成も確定も書かないこと", async () => {
    const written = await writeInAccount(
      async (factory) => (await factory.goals.create({ id: generateRecordId() })).id,
      [
        { type: "achievement", achievedOn: "2026-11-05" },
        { type: "deadline_confirmation", deadlineWeightTrendKg: 70 },
      ],
    );
    expect(written.errors).toEqual([
      "達成を書く目標が、減量・増量の目標ではない",
      "期限の日を確定する目標が、減量・増量の目標ではない",
    ]);
  });
});
