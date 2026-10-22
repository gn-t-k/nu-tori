import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../../domain/record-id";
import { createRecordChangeWriter } from "../../../durable-object/create-record-change-writer";
import { createRecordKindStores } from "../../../durable-object/create-record-kind-stores";
import { regularSubscriptionAccount } from "../../../durable-object/testing/regular-subscription-account";
import { durableObjectTables } from "../../../durable-object/durable-object-tables";
import { durableObjectFactory } from "../../../durable-object/testing/durable-object-factory";
import { writeGoalAchievement } from "../../domain/write-goal-achievement";
import { writeGoalDeadlineConfirmation } from "../../domain/write-goal-deadline-confirmation";

// 新しいアカウントに目標の行を置き、達成と期限の日の確定を順に書く。投げたエラーの文（投げなければ undefined）と、書いたあとの行を返す
export const writeGoalProgressInAccount = (
  seed: (factory: ReturnType<typeof durableObjectFactory>) => Promise<RecordId>,
  writes: readonly GoalProgressWrite[],
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
    const { goal } = createRecordKindStores(state.storage, regularSubscriptionAccount);
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

type GoalProgressWrite =
  | { type: "achievement"; achievedOn: string }
  | { type: "deadline_confirmation"; deadlineWeightTrendKg: number };

const judgedAt = new Date("2026-12-01T03:00:00Z");
