import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { createDishWrite } from "../../dish/http/testing/create-dish-write";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import type { IdentifiedDishes } from "../../estimation/domain/estimation-provider";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { waitForEstimationAttempts } from "../../estimation/http/testing/wait-for-estimation-attempts";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { mockCreateConversationProviderOk } from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { createSentTextWrite } from "./testing/create-sent-text-write";
import { resendSentTextAsConversationWrite } from "./testing/resend-sent-text-as-conversation-write";

// 東京の 2026-10-10（土）08:30
const saturdayMorningInTokyo = Date.UTC(2026, 9, 9, 23, 30);

const dish = (name: string, ingredientName: string): IdentifiedDishes["dishes"][number] => ({
  name,
  quantity: 1,
  unit: "皿",
  ingredients: [
    {
      name: ingredientName,
      quantity: 100,
      unit: "g",
      edibleGramsPerUnit: 1,
      foodCompositionQuery: ingredientName,
      nutritionLabel: undefined,
    },
  ],
});

const recordIdsOf = (changes: PullResult["changes"], kind: string): string[] =>
  changes
    .filter((change) => change.kind === kind)
    .map(({ recordId }) => recordId)
    .toSorted();

describe("会話として送り直す", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    useFakeClock(Date.now() + 86_400_000);
    pullChangesAfter = async (afterSequence) =>
      (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>();
  });

  const sendText = async () => {
    const write = createSentTextWrite({
      sentText: { body: "朝はパン、昼はうどん", sentAt: saturdayMorningInTokyo },
    });
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  const resend = async (sentTextId: string) =>
    (
      await (
        await pushSyncWrites(sessionToken, {
          writes: [resendSentTextAsConversationWrite(sentTextId)],
        })
      ).json<PushResults>()
    ).results[0];

  describe("2つの文章の食事に推定した文章を、会話として送り直したとき", () => {
    let sentTextId: string;
    let beforeResend: PullResult;
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk({
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-10T07:00", dishes: [dish("トースト", "食パン")] },
            { eatenAt: "2026-10-10T08:00", dishes: [dish("かけうどん", "うどん")] },
          ],
        },
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      beforeResend = await pullChangesAfter(0);
      result = await resend(sentTextId);
    });

    test("当てたと返すこと", () => {
      expect(result?.result).toBe("applied");
    });

    test("食事・料理・材料の削除の印と、会話になった文章の状態が一緒に届くこと", async () => {
      const { changes } = await pullChangesAfter(beforeResend.nextAfterSequence);
      expect({
        meals: recordIdsOf(changes, "meal_deletion"),
        dishes: recordIdsOf(changes, "dish_deletion"),
        ingredients: recordIdsOf(changes, "ingredient_deletion"),
        statuses: changes
          .filter(({ kind }) => kind === "sent_text_status")
          .map(({ record }) => record),
      }).toEqual({
        meals: recordIdsOf(beforeResend.changes, "meal"),
        dishes: recordIdsOf(beforeResend.changes, "dish"),
        ingredients: recordIdsOf(beforeResend.changes, "ingredient"),
        statuses: [{ sentTextId, classification: "conversation" }],
      });
    });

    test("きっかけが会話として送り直しの返事の依頼を、ユーザーの最新のタイムゾーンでの今日の分として作ること", async () => {
      expect(
        await readRows(
          accountId,
          `SELECT reply_requests.sent_text_id, reply_requests.counted_on,
                  conversation_resend_reply_requests.reply_request_id IS NOT NULL AS by_conversation_resend
           FROM reply_requests
           LEFT JOIN conversation_resend_reply_requests
             ON conversation_resend_reply_requests.reply_request_id = reply_requests.id`,
        ),
      ).toEqual([
        {
          sent_text_id: sentTextId,
          counted_on: new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(
            Date.now(),
          ),
          by_conversation_resend: 1,
        },
      ]);
    });

    test("使った推定の回数を戻さないこと", async () => {
      expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(1);
    });

    describe("消した食事を消す書き込みと、料理を足す書き込みを送ったとき", () => {
      test("どちらも削除の印に当たったとして捨てること", async () => {
        const [mealId] = recordIdsOf(beforeResend.changes, "meal");
        const response = await pushSyncWrites(sessionToken, {
          writes: [deleteMealWrite(String(mealId)), createDishWrite(String(mealId))],
        });
        expect(
          (await response.json<PushResults>()).results.map(({ result: written }) => written),
        ).toEqual(["ignored_tombstone", "ignored_tombstone"]);
      });
    });

    describe("同じ文章を、もう一度会話として送り直したとき", () => {
      let afterResend: number;
      let again: PushResults["results"][number] | undefined;
      beforeEach(async () => {
        afterResend = (await pullChangesAfter(0)).nextAfterSequence;
        again = await resend(sentTextId);
      });

      test("当てたと返し、変更を足さないこと", async () => {
        expect({
          result: again?.result,
          changes: (await pullChangesAfter(afterResend)).changes,
        }).toEqual({ result: "applied", changes: [] });
      });

      test("返事の依頼を2つ作らないこと", async () => {
        expect(await readRows(accountId, "SELECT id FROM reply_requests")).toHaveLength(1);
      });
    });
  });

  describe("まだ読み分けていない文章を、会話として送り直したとき", () => {
    let sentTextId: string;
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      sentTextId = await sendText();
      result = await resend(sentTextId);
    });

    test("食事と読み分けていないとして受け付けず、送った文章の今の値を添えること", () => {
      expect({
        result: result?.result,
        rejectionReason: result?.rejectionReason,
        current: result?.current,
      }).toEqual({
        result: "rejected",
        rejectionReason: "not_classified_as_meal",
        current: {
          status: "value",
          change: {
            kind: "sent_text",
            recordId: sentTextId,
            record: {
              id: sentTextId,
              body: "朝はパン、昼はうどん",
              sentAt: saturdayMorningInTokyo,
              timeZone: "Asia/Tokyo",
            },
          },
        },
      });
    });

    test("控えの kind で、会話として送り直す書き込みと見分けられること", async () => {
      expect(
        await readRows(
          accountId,
          "SELECT kind, result FROM sync_write_receipts WHERE record_type = 'sent_text' AND kind != 'create'",
        ),
      ).toEqual([{ kind: "resend_as_conversation", result: "rejected" }]);
    });
  });

  describe("知らない文章を、会話として送り直したとき", () => {
    test("見つからないとして受け付けず、文章が無いことを添えること", async () => {
      const result = await resend(generateRecordId());
      expect({
        result: result?.result,
        rejectionReason: result?.rejectionReason,
        current: result?.current,
      }).toEqual({
        result: "rejected",
        rejectionReason: "record_not_found",
        current: { status: "absent" },
      });
    });
  });

  describe("会話と読み分けた文章を、会話として送り直したとき", () => {
    let sentTextId: string;
    let afterClassified: number;
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      afterClassified = (await pullChangesAfter(0)).nextAfterSequence;
      result = await resend(sentTextId);
    });

    test("当てたと返し、変更も返事の依頼も足さないこと", async () => {
      expect({
        result: result?.result,
        changes: (await pullChangesAfter(afterClassified)).changes,
        replyRequests: await readRows(
          accountId,
          `SELECT reply_request_id FROM conversation_resend_reply_requests`,
        ),
      }).toEqual({ result: "applied", changes: [], replyRequests: [] });
    });
  });

  describe("推定の途中で、会話として送り直したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      const { promise: replyAfter, resolve: reply } = Promise.withResolvers<void>();
      mockCreateEstimationProviderOk({
        replyAfter,
        identifiedWrittenMeals: {
          meals: [
            { eatenAt: "2026-10-10T07:00", dishes: [dish("トースト", "食パン")] },
            { eatenAt: "2026-10-10T08:00", dishes: [dish("かけうどん", "うどん")] },
          ],
        },
      });
      sentTextId = await sendText();
      const alarm = runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      await waitForEstimationAttempts(accountId, 1);
      await resend(sentTextId);
      reply();
      await alarm;
    });

    test("届いた推定を捨て、食事も料理も残さないこと", async () => {
      const { changes } = await pullChangesAfter(0);
      expect({
        meals: changes.filter(({ kind }) => kind === "meal"),
        dishes: changes.filter(({ kind }) => kind === "dish"),
        status: changes
          .filter(({ kind }) => kind === "sent_text_status")
          .map(({ record }) => record),
      }).toEqual({
        meals: [],
        dishes: [],
        status: [{ sentTextId, classification: "conversation" }],
      });
    });
  });
});
