import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { signInTestAccount } from "../../http/testing";
import { createSentTextWrite } from "./testing/create-sent-text-write";

describe("送った文章の同期", () => {
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(generateRecordId()));
  });

  const pushOne = async (write: ReturnType<typeof createSentTextWrite>) =>
    (await (await pushSyncWrites(sessionToken, { writes: [write] })).json<PushResults>())
      .results[0];

  describe("送った文章を作る書き込みを送ったとき", () => {
    let write: ReturnType<typeof createSentTextWrite>;
    let response: Response;
    beforeEach(async () => {
      write = createSentTextWrite({
        sentText: {
          body: "昼に親子丼を食べた",
          sentAt: 1_791_000_000_000,
          timeZone: "Asia/Tokyo",
        },
      });
      response = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("当てたと返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { results: [{ writeId: write.id, result: "applied" }] },
      });
    });

    test("取りに行くと、送った文章と、読み分けを待っている状態が届くこと", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      const sentTextId = write.sentText["id"];
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "sent_text",
          recordId: sentTextId,
          record: {
            id: sentTextId,
            body: "昼に親子丼を食べた",
            sentAt: 1_791_000_000_000,
            timeZone: "Asia/Tokyo",
          },
        },
        {
          sequence: expect.any(Number),
          kind: "sent_text_status",
          recordId: sentTextId,
          record: { sentTextId, classification: "pending", replyStatus: "none" },
        },
      ]);
    });

    describe("同じ文章の ID で、別の書き込みの ID の作る書き込みを送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        result = await pushOne(createSentTextWrite({ sentText: { id: write.sentText["id"] } }));
      });

      test("捨てること", () => {
        expect(result?.result).toBe("ignored_duplicate");
      });
    });
  });

  describe("受け付ける長さ", () => {
    describe("空白だけの文章を送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        result = await pushOne(createSentTextWrite({ sentText: { body: " 　\n" } }));
      });

      test("範囲の外として受け付けないこと", () => {
        expect(result?.rejectionReason).toBe("out_of_range");
      });
    });

    describe("前後の空白を除いて 501 字の文章を送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        result = await pushOne(createSentTextWrite({ sentText: { body: "あ".repeat(501) } }));
      });

      test("範囲の外として受け付けないこと", () => {
        expect(result?.rejectionReason).toBe("out_of_range");
      });
    });

    describe("500 字ちょうどの文章を送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        result = await pushOne(createSentTextWrite({ sentText: { body: "あ".repeat(500) } }));
      });

      test("受け付けること", () => {
        expect(result?.result).toBe("applied");
      });
    });

    describe("前後に空白がついた 500 字の文章を送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        result = await pushOne(
          createSentTextWrite({ sentText: { body: ` \n${"あ".repeat(500)}　 ` } }),
        );
      });

      test("受け付けること", () => {
        expect(result?.result).toBe("applied");
      });
    });

    describe("サロゲートペアの絵文字 500 字の文章を送ったとき", () => {
      let result: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        // UTF-16 では 1000 単位になるが、コードポイントでは 500
        result = await pushOne(createSentTextWrite({ sentText: { body: "🍙".repeat(500) } }));
      });

      test("受け付けること", () => {
        expect(result?.result).toBe("applied");
      });
    });
  });

  describe("知らないタイムゾーンの作る書き込みを送ったとき", () => {
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      result = await pushOne(createSentTextWrite({ sentText: { timeZone: "Asia/Nowhere" } }));
    });

    test("範囲の外として受け付けないこと", () => {
      expect(result?.rejectionReason).toBe("out_of_range");
    });
  });
});
