import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId } from "../domain/record-id";
import type { RecordChangeWriter } from "../domain/record-change-writer";
import { createRecordChangeWriter } from "./create-record-change-writer";
import { durableObjectTables } from "./durable-object-tables";
import { durableObjectFactory } from "./testing/durable-object-factory";

type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;
type Run = Parameters<RecordChangeWriter>[0];

type Written = {
  returned: unknown;
  // run が投げたエラーの文。投げなければ undefined
  error: string | undefined;
  // 変更の並び。通し番号の順
  changes: unknown[];
  rows: Record<string, unknown[]>;
};

// 書く前の行を seed で作り、入口で run を書いて、書いたあとの変更の並びと行を返す
const writeInAccount = (seed: Seed, run: Run): Promise<Written> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    let returned: unknown;
    let error: string | undefined;
    try {
      returned = createRecordChangeWriter(state.storage)(run);
    } catch (thrown) {
      error = thrown instanceof Error ? thrown.message : String(thrown);
    }
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    return {
      returned,
      error,
      changes: read("SELECT record_type, record_id FROM record_changes ORDER BY sequence"),
      rows: {
        changesOfReceipts: read("SELECT record_change_sequence FROM sync_write_record_changes"),
        schedules: read("SELECT id FROM estimation_schedules"),
        requests: read("SELECT id FROM reply_requests"),
      },
    };
  });

const mealId = generateRecordId();
const dishId = generateRecordId();
const sentTextId = generateRecordId();
const requestId = generateRecordId();
const scheduledAt = new Date("2026-01-01T00:00:00Z");

describe("記録の変化を書く入口", () => {
  describe("変えた記録を足すとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async () => {},
        ({ addChange }) => {
          addChange({ recordType: "meal", recordId: mealId });
          addChange({ recordType: "dish", recordId: dishId });
          return "run の戻り値";
        },
      );
    });

    test("足した順に、変更の並びに載ること", () => {
      expect(written.changes).toEqual([
        { record_type: "meal", record_id: mealId },
        { record_type: "dish", record_id: dishId },
      ]);
    });

    test("変更を控えと結ばないこと", () => {
      expect(written.rows["changesOfReceipts"]).toEqual([]);
    });

    test("run の戻り値を返すこと", () => {
      expect(written.returned).toBe("run の戻り値");
    });
  });

  describe("推定の出来事を書くとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.meals.create({ id: mealId });
        },
        ({ addChange, estimationAt }) => {
          estimationAt(scheduledAt).scheduleMeal({
            id: "schedule-1",
            mealId,
            dueAt: scheduledAt,
            countedOn: "2026-01-01",
          });
          addChange({ recordType: "meal", recordId: mealId });
        },
      );
    });

    test("出来事が書かれること", () => {
      expect(written.rows["schedules"]).toEqual([{ id: "schedule-1" }]);
    });

    test("変わった推定の状態の変更が、run が足した変更のあとに載ること", () => {
      expect(written.changes).toEqual([
        { record_type: "meal", record_id: mealId },
        { record_type: "meal_estimation_status", record_id: mealId },
      ]);
    });
  });

  describe("返事の流れの出来事を書くとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.sentTexts.create({ id: sentTextId });
          await factory.sentTextClassifications.create({ sentTextId });
        },
        ({ reply }) => {
          reply.request({
            id: requestId,
            sentTextId,
            countedOn: "2026-01-01",
            trigger: { type: "classification" },
          });
        },
      );
    });

    test("出来事が書かれること", () => {
      expect(written.rows["requests"]).toEqual([{ id: requestId }]);
    });

    test("変わった送った文章の状態の変更が載ること", () => {
      expect(written.changes).toEqual([{ record_type: "sent_text_status", record_id: sentTextId }]);
    });
  });

  describe("書いたあとに run が失敗したとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.meals.create({ id: mealId });
        },
        ({ addChange, estimationAt }) => {
          addChange({ recordType: "meal", recordId: mealId });
          estimationAt(scheduledAt).scheduleMeal({
            id: "schedule-1",
            mealId,
            dueAt: scheduledAt,
            countedOn: "2026-01-01",
          });
          throw new Error("書いたあとの失敗");
        },
      );
    });

    test("失敗を投げること", () => {
      expect(written.error).toBe("書いたあとの失敗");
    });

    test("変更も出来事も残らないこと（1つのトランザクションで書く）", () => {
      expect({ changes: written.changes, schedules: written.rows["schedules"] }).toEqual({
        changes: [],
        schedules: [],
      });
    });
  });
});
