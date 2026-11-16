import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { createSentTextWrite } from "../../sent-text/http/testing/create-sent-text-write";
import { app } from "../app";
import { putMealPhoto } from "../meal-photo-routes/testing/put-meal-photo";
import { pushSyncWrites, type PushResults } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { signInTestAccount } from "../testing";

describe("要求の本文の大きさの上限", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
  });

  describe("同期の書き込みの本文が 2 MiB を超えるとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createSentTextWrite({ sentText: { body: "あ".repeat(2 * 1024 * 1024) } })],
      });
    });

    test("413 を返すこと", () => {
      expect(response.status).toBe(413);
    });

    test("要求の控えを残さないこと", async () => {
      expect(await readRows(accountId, "SELECT sync_request_log_id FROM sync_push_logs")).toEqual(
        [],
      );
    });
  });

  describe("500 文字の送った文章を 500 件並べた同期の書き込みのとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: Array.from({ length: 500 }, () =>
          createSentTextWrite({ sentText: { body: "あ".repeat(500) } }),
        ),
      });
    });

    test("書き込みごとの結果を返すこと", async () => {
      expect((await response.json<PushResults>()).results).toHaveLength(500);
    });
  });

  describe("本文の長さを告げずに、2 MiB を超える同期の書き込みを流して送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      const chunk = new TextEncoder().encode("a".repeat(64 * 1024));
      let sentChunks = 0;
      response = await app.request(
        "/v1/sync/writes",
        {
          method: "POST",
          headers: {
            authorization: `Bearer ${sessionToken}`,
            "content-type": "application/json",
          },
          body: new ReadableStream<Uint8Array>({
            pull: (controller) => {
              if (sentChunks === 33) {
                controller.close();
                return;
              }
              sentChunks += 1;
              controller.enqueue(chunk);
            },
          }),
        },
        env,
      );
    });

    test("413 を返すこと", () => {
      expect(response.status).toBe(413);
    });
  });

  describe("ほかの JSON の口の本文が 64 KiB を超えるとき", () => {
    test("POST /v1/sessions が 413 を返すこと", async () => {
      expect((await postOversizedJson("/v1/sessions", sessionToken)).status).toBe(413);
    });

    test("POST /v1/goal-setup/previews が 413 を返すこと", async () => {
      expect((await postOversizedJson("/v1/goal-setup/previews", sessionToken)).status).toBe(413);
    });

    test("POST /v1/subscription-transactions が 413 を返すこと", async () => {
      expect((await postOversizedJson("/v1/subscription-transactions", sessionToken)).status).toBe(
        413,
      );
    });

    test("POST /v1/terms-agreements が 413 を返すこと", async () => {
      expect((await postOversizedJson("/v1/terms-agreements", sessionToken)).status).toBe(413);
    });

    test("POST /v1/app-store-server-notifications が 413 を返すこと", async () => {
      expect(
        (await postOversizedJson("/v1/app-store-server-notifications", sessionToken)).status,
      ).toBe(413);
    });
  });

  describe("64 KiB を超える写真を送ったとき", () => {
    test("写真の口の上限で受けること", async () => {
      const response = await putMealPhoto(sessionToken, generateRecordId(), {
        body: createLargePhotoBytes(),
        contentType: "image/jpeg",
      });
      expect(response.status).toBe(204);
    });
  });
});

// JPEG の先頭の印から始まる 1 MiB
const createLargePhotoBytes = (): Uint8Array => {
  const bytes = new Uint8Array(1024 * 1024);
  bytes.set([0xff, 0xd8, 0xff]);
  return bytes;
};

const postOversizedJson = (path: string, sessionToken: string) =>
  app.request(
    path,
    {
      method: "POST",
      headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
      body: JSON.stringify({ padding: "a".repeat(64 * 1024) }),
    },
    env,
  );
