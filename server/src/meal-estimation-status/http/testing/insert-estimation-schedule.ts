import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 推定の予定を作る経路（写真の受け取り・アラーム）がまだ無いので、出来事の行を直に書く。
// progress は、その予定がどこまで進んだか
export const insertEstimationSchedule = (
  accountId: string,
  mealId: string,
  schedule: {
    dueAt: number;
    progress: "waiting" | "deferred" | "started" | "estimated" | "no_dishes" | "abandoned";
  },
) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const { sql } = state.storage;
    const scheduleId = generateRecordId();
    sql.exec(
      "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, ?, ?)",
      scheduleId,
      schedule.dueAt,
      new Date(schedule.dueAt).toISOString().slice(0, 10),
    );
    sql.exec(
      "INSERT INTO meal_estimation_schedules (estimation_schedule_id, meal_id) VALUES (?, ?)",
      scheduleId,
      mealId,
    );
    if (schedule.progress === "waiting") {
      return;
    }
    if (schedule.progress === "deferred") {
      sql.exec(
        "INSERT INTO estimation_deferrals (estimation_schedule_id, deferred_at) VALUES (?, ?)",
        scheduleId,
        schedule.dueAt,
      );
      return;
    }
    const estimationId = generateRecordId();
    sql.exec(
      "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, ?)",
      estimationId,
      scheduleId,
      schedule.dueAt,
    );
    if (schedule.progress === "estimated" || schedule.progress === "no_dishes") {
      sql.exec(
        "INSERT INTO estimation_completions (estimation_id, completed_at, result) VALUES (?, ?, ?)",
        estimationId,
        schedule.dueAt,
        schedule.progress,
      );
    }
    if (schedule.progress === "abandoned") {
      sql.exec(
        "INSERT INTO estimation_abandonments (estimation_id, abandoned_at) VALUES (?, ?)",
        estimationId,
        schedule.dueAt,
      );
    }
  });
