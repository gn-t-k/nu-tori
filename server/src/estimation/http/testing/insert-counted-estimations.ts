import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 食事につながらない推定を、数える日 countedOn の分として count 回ぶん書く。アラームは続きとして拾わず、回数にだけ数える
export const insertCountedEstimations = (accountId: string, countedOn: string, count: number) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    for (let index = 0; index < count; index += 1) {
      const scheduleId = generateRecordId();
      state.storage.sql.exec(
        "INSERT INTO estimation_schedules (id, due_at, counted_on) VALUES (?, ?, ?)",
        scheduleId,
        0,
        countedOn,
      );
      state.storage.sql.exec(
        "INSERT INTO estimations (id, estimation_schedule_id, started_at) VALUES (?, ?, ?)",
        generateRecordId(),
        scheduleId,
        0,
      );
    }
  });
