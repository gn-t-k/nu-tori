import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { createPhotoBytes } from "../src/http/meal-photo-routes/testing/create-photo-bytes";
import { app } from "../src/http/app";
import { mockCreateEstimationProviderOk } from "../src/estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { mockCreateConversationProviderOk } from "../src/reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { mealTextBody, runMainFlow } from "./run-main-flow";

const signInSecret = "e2e-sign-in-secret-0123456789abcdef0123456789";

// 開発用の環境の Worker を、この実行環境の中の本物の経路で受ける
describe("開発用の環境で主な流れを確かめる流れ", () => {
  let deployedEnv: Env;
  let flowOptions: Parameters<typeof runMainFlow>[0];
  let messages: string[];
  // 流れが作ったアカウント。ほかのテストも同じ D1 にアカウントを作るので、全体の数でなく、この ID で数える
  let createdAccountId: string | undefined;
  const countCreatedAccount = async () =>
    (
      await env.DB.prepare(`SELECT COUNT(*) AS count FROM "user" WHERE "id" = ?`)
        .bind(createdAccountId ?? "")
        .first<{ count: number }>()
    )?.count;
  beforeEach(() => {
    createdAccountId = undefined;
    deployedEnv = { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: signInSecret };
    messages = [];
    flowOptions = {
      baseUrl: "https://api-dev.example.test",
      signInSecret,
      photo: createPhotoBytes(),
      send: async (url, init) => {
        const response = await app.request(url, init, deployedEnv);
        if (url.endsWith("/v1/e2e/sessions") && response.status === 201) {
          createdAccountId = (await response.clone().json<{ accountId: string }>()).accountId;
        }
        return response;
      },
      estimationTimeoutMs: 20_000,
      replyTimeoutMs: 20_000,
      pollIntervalMs: 50,
      log: (message) => messages.push(message),
    };
  });

  describe("写真と文章の食事が推定でき、会話の文章に返事が作れるとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk();
      mockCreateConversationProviderOk({
        classification: (body) => (body === mealTextBody ? "meal" : "conversation"),
        reply: { body: "よく歩けましたね。", mealIds: [], textDeltas: ["よく歩けました", "ね。"] },
      });
    });

    test("最後まで通り、作ったアカウントを消すこと", async () => {
      await runMainFlow(flowOptions);
      expect({
        created: createdAccountId !== undefined,
        remaining: await countCreatedAccount(),
      }).toEqual({
        created: true,
        remaining: 0,
      });
    });

    test("通った段を順に知らせること", async () => {
      await runMainFlow(flowOptions);
      expect(messages).toEqual([
        "サインインした",
        "体重を記録した",
        "写真の食事を送った",
        "推定できた（料理 2、材料 3）",
        "推定でできた料理の名前を直した",
        "食事の文章を送った",
        "文章の食事が推定できた（料理 2、材料 3）",
        "会話の文章を送った",
        "見守る要求で返事が届いた（流れた分 2）",
        "取りに行くで返事が届いた",
        "アカウントを削除した",
      ]);
    });
  });

  describe("食事の文章が会話と読み分けられたとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk();
      mockCreateConversationProviderOk({ classification: "conversation" });
    });

    test("読み分けの結果を知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "食事の文章が conversation と読み分けられた",
      );
      expect(await countCreatedAccount()).toBe(0);
    });
  });

  describe("会話の文章が食事と読み分けられたとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk();
      mockCreateConversationProviderOk({ classification: "meal" });
    });

    test("見守る要求が閉じたときの結果を知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        '会話の文章の見守る要求が、返事ありでなく {"type":"classified_as_meal"} で閉じた',
      );
      expect(await countCreatedAccount()).toBe(0);
    });
  });

  describe("写真に料理が無いと推定されるとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk({ identifiedDishes: { dishes: [] } });
    });

    test("推定できなかった状態を知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "推定できたにならず、no_dishes で終わった",
      );
      expect(await countCreatedAccount()).toBe(0);
    });
  });

  describe("推定が時間内に終わらないとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk({ replyAfter: new Promise(() => {}) });
      flowOptions = { ...flowOptions, estimationTimeoutMs: 500 };
    });

    test("待った時間と最後の状態を知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "推定できたにならないまま 500 ミリ秒たった（最後の状態: estimating）",
      );
      expect(await countCreatedAccount()).toBe(0);
    });
  });

  describe("サインインの口が閉じているとき", () => {
    beforeEach(() => {
      deployedEnv = { ...env, E2E_SIGN_IN_SECRET: undefined };
    });

    test("口が閉じていることを知らせて失敗すること", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "サインインの口が閉じている（開発用の Worker に E2E_SIGN_IN_SECRET を置く）",
      );
    });
  });

  describe("サインインの口の秘密の値が違うとき", () => {
    beforeEach(() => {
      flowOptions = { ...flowOptions, signInSecret: `${signInSecret}x` };
    });

    test("秘密の値が合わないことを知らせて失敗すること", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "サインインの秘密の値が合わない（GitHub の Environment と Worker の E2E_SIGN_IN_SECRET を同じにする）",
      );
    });
  });
});
