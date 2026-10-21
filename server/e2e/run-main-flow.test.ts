import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { createPhotoBytes } from "../src/http/meal-photo-routes/testing/create-photo-bytes";
import { app } from "../src/http/app";
import { mockCreateEstimationProviderOk } from "../src/estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { mockCreateConversationProviderOk } from "../src/reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { mealTextBody } from "./meal-text-body";
import { runMainFlow } from "./run-main-flow";
import { e2eRequestHeaders } from "../src/http/e2e-session-routes/e2e-request-headers";

const signInSecret = "e2e-sign-in-secret-0123456789abcdef0123456789";

// 開発用の環境の Worker を、この実行環境の中の本物の経路で受ける
describe("開発用の環境で主な流れを確かめる流れ", () => {
  let deployedEnv: Env;
  let flowOptions: Parameters<typeof runMainFlow>[0];
  let messages: string[];
  // 流れが作ったアカウント。ほかのテストも同じ D1 にアカウントを作るので、全体の数でなく、この ID で数える
  let createdAccountIds: string[];
  const countCreatedAccounts = async () =>
    (
      await env.DB.prepare(
        `SELECT COUNT(*) AS count FROM "user" WHERE "id" IN (SELECT value FROM json_each(?))`,
      )
        .bind(JSON.stringify(createdAccountIds))
        .first<{ count: number }>()
    )?.count;
  beforeEach(() => {
    createdAccountIds = [];
    deployedEnv = { ...env, SENTRY_ENVIRONMENT: "development", E2E_SIGN_IN_SECRET: signInSecret };
    messages = [];
    flowOptions = {
      baseUrl: "https://api-dev.example.test",
      signInSecret,
      photo: createPhotoBytes(),
      send: async (url, init) => {
        const response = await app.request(url, init, deployedEnv);
        if (url.endsWith("/v1/e2e/sessions") && response.status === 201) {
          createdAccountIds.push((await response.clone().json<{ accountId: string }>()).accountId);
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

    test("最後まで通り、作ったアカウントをどれも消すこと", async () => {
      await runMainFlow(flowOptions);
      expect({
        created: createdAccountIds.length,
        remaining: await countCreatedAccounts(),
      }).toEqual({
        created: 2,
        remaining: 0,
      });
    });

    test("通った段を順に知らせること", async () => {
      await runMainFlow(flowOptions);
      expect(messages).toEqual([
        "サインインした",
        "無料体験中のアカウントだった",
        "7日前の体重を記録した",
        "目標の下見で、逆算できず、身体データを添えると減量の案を出せると答えた",
        "目標案を受け取った（推定消費カロリーの出どころ formula）",
        "7日前に目標を決めた（goal・daily_guide・expenditure_estimate）",
        "同じ要求の ID の再送が、同じ応答で返った",
        "取りに行くで目標と1日の目安と推定消費カロリーが届いた",
        "取りに行くで週の見直しが届いた（見送りの理由 within_first_week）",
        "写真の食事を送った",
        "推定できた（料理 2、材料 3）",
        "推定でできた料理の名前を直した",
        "食事の文章を送った",
        "文章の食事が推定できた（料理 2、材料 3）",
        "会話の文章を送った",
        "見守る要求で返事が届いた（流れた分 2）",
        "取りに行くで返事が届いた",
        "アカウントを削除した",
        "60日前に使い始めたことにしてサインインした",
        "無料体験の終わったアカウントだった",
        "無料体験の終わったアカウントで写真の食事を送った",
        "推定がサブスクリプションを待っているになった",
        "無料体験の終わったアカウントを削除した",
      ]);
    });
  });

  // 課金を入れた日が30日より前でない Worker と同じく、2つ目のアカウントの無料体験が終わらない。
  // Durable Object は Worker に渡した環境でなくこの実行環境の設定を読むので、使い始めた日の差し替えを外して作る
  describe("2つ目のアカウントの無料体験が終わっていないとき", () => {
    beforeEach(() => {
      mockCreateEstimationProviderOk();
      mockCreateConversationProviderOk({
        classification: (body) => (body === mealTextBody ? "meal" : "conversation"),
      });
      const { send } = flowOptions;
      flowOptions = {
        ...flowOptions,
        send: (url, init) => {
          const { [e2eRequestHeaders.requestedAt]: _, ...headers } = Object.fromEntries(
            new Headers(init.headers),
          );
          return send(url, url.endsWith("/v1/e2e/sessions") ? { ...init, headers } : init);
        },
      };
    });

    test("課金を入れた日を直すよう知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "60日前に使い始めたことにしても、無料体験が終わっていない（開発用の BILLING_STARTED_ON を30日より前の日にする。最後の日: ",
      );
      expect(await countCreatedAccounts()).toBe(0);
    });
  });

  describe("目標の設定の要求の経路が無い Worker のとき", () => {
    beforeEach(() => {
      const { send } = flowOptions;
      flowOptions = {
        ...flowOptions,
        send: (url, init) =>
          url.includes("/v1/goal-setup/")
            ? Promise.resolve(new Response(null, { status: 404 }))
            : send(url, init),
      };
    });

    test("断られた要求と状態コードを知らせて失敗し、アカウントは消すこと", async () => {
      await expect(runMainFlow(flowOptions)).rejects.toThrow(
        "目標の設定の要求 preview が断られた（状態コード 404、理由: なし）",
      );
      expect(await countCreatedAccounts()).toBe(0);
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
      expect(await countCreatedAccounts()).toBe(0);
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
      expect(await countCreatedAccounts()).toBe(0);
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
      expect(await countCreatedAccounts()).toBe(0);
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
      expect(await countCreatedAccounts()).toBe(0);
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
