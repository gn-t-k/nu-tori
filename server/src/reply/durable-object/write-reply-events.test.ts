import { env, runInDurableObject } from "cloudflare:test";
import { drizzle } from "drizzle-orm/durable-sqlite";
import { beforeEach, describe, expect, test } from "vitest";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import { createRecordKindStores } from "../../durable-object/create-record-kind-stores";
import { durableObjectTables } from "../../durable-object/durable-object-tables";
import { durableObjectFactory } from "../../durable-object/testing/durable-object-factory";
import type { ReplyWrites } from "../domain/reply-writes";

// 返事の書き込みの口（ドメイン層の writeReplyEvents）を、Durable Object の置き場で組んだ形で確かめる。
// ドメイン層のテストは cloudflare:test を import できないので、ここに置く
type Seed = (factory: ReturnType<typeof durableObjectFactory>) => Promise<void>;
type Run = (writes: ReplyWrites) => void;

type Written = {
  changes: RecordChangeTarget<string>[];
  // run が投げたエラーの文。投げなければ undefined
  error: string | undefined;
  rows: Record<string, unknown[]>;
};

// 書く前の行を seed で作り、run を呼び出し側のトランザクションの中で書いて、足された変更と書いたあとの行を返す
const writeInAccount = (seed: Seed, run: Run): Promise<Written> =>
  runInDurableObject(env.ACCOUNT.get(env.ACCOUNT.newUniqueId()), async (_, state) => {
    await seed(durableObjectFactory(drizzle(state.storage, { schema: durableObjectTables })));
    const changes: RecordChangeTarget<string>[] = [];
    let error: string | undefined;
    try {
      state.storage.transactionSync(() => {
        createRecordKindStores(state.storage).writeReplyEvents((change) => {
          changes.push(change);
        }, run);
      });
    } catch (thrown) {
      error = thrown instanceof Error ? thrown.message : String(thrown);
    }
    const read = (query: string) => state.storage.sql.exec(query).toArray();
    return {
      changes: error === undefined ? changes : [],
      error,
      rows: {
        requests: read("SELECT id, sent_text_id, counted_on FROM reply_requests"),
        classificationTriggers: read("SELECT reply_request_id FROM classification_reply_requests"),
        resendTriggers: read("SELECT reply_request_id FROM resend_reply_requests"),
        conversationResendTriggers: read(
          "SELECT reply_request_id FROM conversation_resend_reply_requests",
        ),
        halts: read("SELECT reply_request_id FROM reply_request_halts"),
        generations: read("SELECT id FROM reply_generations"),
        utterances: read("SELECT reply_generation_id FROM ai_utterances"),
        abandonments: read("SELECT reply_generation_id FROM reply_generation_abandonments"),
      },
    };
  });

const sentTextId: RecordId = generateRecordId();
const generationId: RecordId = generateRecordId();
const requestId: RecordId = generateRecordId();
const requestedAt = new Date("2026-01-01T03:00:01Z");

// 会話と読み分けた文章の、きっかけが読み分けの依頼
const seedRequest = async (factory: ReturnType<typeof durableObjectFactory>) => {
  await factory.sentTexts.create({ id: sentTextId });
  await factory.sentTextClassifications.create({ sentTextId });
  await factory.replyRequests.create({ id: requestId, sentTextId });
  await factory.classificationReplyRequests.create({ replyRequestId: requestId });
};

// 依頼の生成
const seedGeneration = async (factory: ReturnType<typeof durableObjectFactory>) => {
  await seedRequest(factory);
  await factory.replyGenerations.create({ id: generationId, replyRequestId: requestId });
};

describe("返事の書き込みの口", () => {
  describe("会話と読み分けた文章に依頼を書くとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.sentTexts.create({ id: sentTextId });
          await factory.sentTextClassifications.create({ sentTextId });
        },
        (writes) => {
          writes.request({
            id: requestId,
            sentTextId,
            countedOn: "2026-01-01",
            trigger: { type: "classification" },
          });
        },
      );
    });

    test("依頼と、きっかけのサブセットがちょうど1つ書かれること", () => {
      expect({
        requests: written.rows["requests"],
        classificationTriggers: written.rows["classificationTriggers"],
        resendTriggers: written.rows["resendTriggers"],
        conversationResendTriggers: written.rows["conversationResendTriggers"],
      }).toEqual({
        requests: [{ id: requestId, sent_text_id: sentTextId, counted_on: "2026-01-01" }],
        classificationTriggers: [{ reply_request_id: requestId }],
        resendTriggers: [],
        conversationResendTriggers: [],
      });
    });

    test("応答待ちになった送った文章の状態の変更を足すこと", () => {
      expect(written.changes).toEqual([{ recordType: "sent_text_status", recordId: sentTextId }]);
    });
  });

  describe("依頼を書いたあとに、呼び出し側のトランザクションが失敗したとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.sentTexts.create({ id: sentTextId });
          await factory.sentTextClassifications.create({ sentTextId });
        },
        (writes) => {
          writes.request({
            id: requestId,
            sentTextId,
            countedOn: "2026-01-01",
            trigger: { type: "classification" },
          });
          throw new Error("依頼のあとの失敗");
        },
      );
    });

    test("依頼もきっかけも残らないこと（同じトランザクションで書く）", () => {
      expect({
        requests: written.rows["requests"],
        classificationTriggers: written.rows["classificationTriggers"],
      }).toEqual({ requests: [], classificationTriggers: [] });
    });
  });

  describe("食事と読み分けた文章に依頼を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.sentTexts.create({ id: sentTextId });
          await factory.sentTextClassifications.create({ sentTextId, result: "meal" });
        },
        (writes) => {
          writes.request({
            id: requestId,
            sentTextId,
            countedOn: "2026-01-01",
            trigger: { type: "classification" },
          });
        },
      );
    });

    test("投げて、依頼を書かないこと", () => {
      expect({ error: written.error, requests: written.rows["requests"] }).toEqual({
        error: expect.stringContaining("会話と読み分けていない文章"),
        requests: [],
      });
    });
  });

  describe("読み分ける前の文章に依頼を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await factory.sentTexts.create({ id: sentTextId });
        },
        (writes) => {
          writes.request({
            id: requestId,
            sentTextId,
            countedOn: "2026-01-01",
            trigger: { type: "classification" },
          });
        },
      );
    });

    test("投げて、依頼を書かないこと", () => {
      expect({ error: written.error, requests: written.rows["requests"] }).toEqual({
        error: expect.stringContaining("会話と読み分けていない文章"),
        requests: [],
      });
    });
  });

  describe("生成を始めた依頼を回数切れにしようとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await seedGeneration(factory);
        },
        (writes) => {
          writes.halt({ requestId, haltedAt: requestedAt });
        },
      );
    });

    test("投げて、回数切れを書かないこと", () => {
      expect({ error: written.error, halts: written.rows["halts"] }).toEqual({
        error: expect.stringContaining("生成を始めた依頼を回数切れに"),
        halts: [],
      });
    });
  });

  describe("回数切れの依頼の生成を始めようとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await seedRequest(factory);
          await factory.replyRequestHalts.create({ replyRequestId: requestId });
        },
        (writes) => {
          writes.beginGeneration({
            id: generationId,
            requestId,
            startedAt: requestedAt,
          });
        },
      );
    });

    test("投げて、生成を書かないこと", () => {
      expect({ error: written.error, generations: written.rows["generations"] }).toEqual({
        error: expect.stringContaining("回数切れの依頼の生成を始め"),
        generations: [],
      });
    });
  });

  describe("作れなかった生成に返事を書こうとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await seedGeneration(factory);
          await factory.replyGenerationAbandonments.create({ replyGenerationId: generationId });
        },
        (writes) => {
          writes.reply({ generationId, body: "返事", mealIds: [] });
        },
      );
    });

    test("投げて、返事を書かないこと", () => {
      expect({ error: written.error, utterances: written.rows["utterances"] }).toEqual({
        error: expect.stringContaining("作れなかった生成に返事を"),
        utterances: [],
      });
    });
  });

  describe("返事を書いた生成を作れなかったにしようとしたとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await seedGeneration(factory);
          await factory.aiUtterances.create({ replyGenerationId: generationId });
        },
        (writes) => {
          writes.abandon({ generationId, abandonedAt: requestedAt });
        },
      );
    });

    test("投げて、作れなかったを書かないこと", () => {
      expect({ error: written.error, abandonments: written.rows["abandonments"] }).toEqual({
        error: expect.stringContaining("返事を書いた生成を作れなかった"),
        abandonments: [],
      });
    });
  });

  describe("生成に返事を書くとき", () => {
    let written: Written;
    beforeEach(async () => {
      written = await writeInAccount(
        async (factory) => {
          await seedGeneration(factory);
        },
        (writes) => {
          writes.reply({ generationId, body: "返事", mealIds: [] });
        },
      );
    });

    test("返事の変更と、返事ありになった送った文章の状態の変更を足すこと", () => {
      expect(written.changes).toEqual([
        { recordType: "ai_utterance", recordId: generationId },
        { recordType: "sent_text_status", recordId: sentTextId },
      ]);
    });
  });
});
