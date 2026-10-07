import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { createDishWrite } from "../../dish/http/testing/create-dish-write";
import { updateDishWrite } from "../../dish/http/testing/update-dish-write";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { putMealPhoto } from "../../http/meal-photo-routes/testing/put-meal-photo";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { mockCreateEstimationProviderOk } from "../durable-object/create-estimation-provider/create-estimation-provider.mock";
import { readIdentifyDishesRequests } from "./testing/read-identify-dishes-requests";
import { runEstimationAlarm } from "./testing/run-estimation-alarm";
import { useFakeClock } from "./testing/use-fake-clock";
import { beforeEach, describe, expect, test } from "vitest";

const oneHourMs = 3_600_000;

// 写真を待っている食事に足した料理の推定し直し（#332 の「推定し直し」の「写真を待つ」）。
// 写真1枚の食事を、写真を送らずに送ってから、料理を足す
describe("写真を待っている食事に料理を足したとき", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let provider: ReturnType<typeof mockCreateEstimationProviderOk>;
  let mealId: string;
  let photoId: string;
  let dishId: string;
  let addedAt: number;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 86_400_000);
    provider = mockCreateEstimationProviderOk();
    mealId = generateRecordId();
    photoId = generateRecordId();
    await pushSyncWrites(sessionToken, {
      writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
    });
    clock.advance(1000);
    const write = createDishWrite(mealId, { name: "味噌汁", positionInMeal: 3 });
    dishId = write.dishId;
    addedAt = Date.now();
    await pushSyncWrites(sessionToken, { writes: [write] });
  });

  const readAlarmAt = () =>
    runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
      state.storage.getAlarm(),
    );
  const readDishStatus = async () =>
    (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes.find(
      ({ kind, recordId }) => kind === "dish_estimation_status" && recordId === dishId,
    )?.record["status"];

  test("アラームを、写真を待つ時間を過ぎる時刻に張ること", async () => {
    expect(await readAlarmAt()).toBe(addedAt + oneHourMs);
  });

  describe("写真が届く前にアラームが動いたとき", () => {
    beforeEach(async () => {
      await runEstimationAlarm(accountId);
    });

    test("推定を始めず、その日の推定の回数に数えないこと", async () => {
      expect({
        requests: readIdentifyDishesRequests(provider).length,
        estimations: await readRows(accountId, "SELECT id FROM estimations"),
      }).toEqual({ requests: 0, estimations: [] });
    });

    test("料理ごとの推定の状態は推定中のままであること", async () => {
      expect(await readDishStatus()).toBe("estimating");
    });

    test("見送りを足さないこと", async () => {
      expect(await readRows(accountId, "SELECT * FROM estimation_deferrals")).toEqual([]);
    });
  });

  describe("待つあいだに名前を直したとき", () => {
    beforeEach(async () => {
      clock.advance(1000);
      await pushSyncWrites(sessionToken, { writes: [updateDishWrite(dishId, { name: "豚汁" })] });
      await runEstimationAlarm(accountId);
    });

    test("名前を直した料理も、写真が届くまで推定を始めないこと", () => {
      expect(readIdentifyDishesRequests(provider)).toEqual([]);
    });

    test("アラームを、名前を直した書き込みから写真を待つ時間を過ぎる時刻に張ること", async () => {
      expect(await readAlarmAt()).toBe(addedAt + 1000 + oneHourMs);
    });
  });

  describe("写真が届いてからアラームが動いたとき", () => {
    beforeEach(async () => {
      clock.advance(1000);
      await putMealPhoto(sessionToken, photoId);
      await runEstimationAlarm(accountId);
    });

    test("① に、食事の写真と料理の名前を渡して推定し直すこと", () => {
      expect(
        readIdentifyDishesRequests(provider)
          .filter(({ target }) => target.type === "dish")
          .map(({ photos, target }) => ({ photoCount: photos.length, target })),
      ).toEqual([
        {
          photoCount: 1,
          target: { type: "dish", dish: expect.objectContaining({ name: "味噌汁" }) },
        },
      ]);
    });

    test("食事の推定の ① に、足した料理の名前を渡すこと", () => {
      expect(
        readIdentifyDishesRequests(provider)
          .filter(({ target }) => target.type === "meal")
          .map(({ target }) => target),
      ).toEqual([{ type: "meal", addedDishNames: ["味噌汁"] }]);
    });

    test("食事の推定が作った料理を、足した料理の後ろに並べること", async () => {
      expect(
        (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
          .filter(({ kind }) => kind === "dish")
          .map(({ record }) => `${String(record["positionInMeal"])} ${String(record["name"])}`)
          .toSorted(),
      ).toEqual(["3 味噌汁", "4 親子丼", "5 緑茶"]);
    });

    test("始めたときに、その日の推定の回数に数えること", async () => {
      // 食事の推定と、料理の推定し直し
      expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(2);
    });
  });

  describe("写真が届かないまま待つ時間を過ぎてアラームが動いたとき", () => {
    beforeEach(async () => {
      clock.advance(oneHourMs);
      await runEstimationAlarm(accountId);
    });

    test("① に、写真を渡さず料理の名前だけで推定し直すこと", () => {
      expect(
        readIdentifyDishesRequests(provider).map(({ photos, target }) => ({
          photoCount: photos.length,
          target,
        })),
      ).toEqual([
        {
          photoCount: 0,
          target: { type: "dish", dish: expect.objectContaining({ name: "味噌汁" }) },
        },
      ]);
    });

    test("始めたときに、その日の推定の回数に数えること", async () => {
      expect(await readRows(accountId, "SELECT id FROM estimations")).toHaveLength(1);
    });

    test("名前だけで推定した量が料理に当たること", async () => {
      expect(await readDishStatus()).toBe("estimated");
    });
  });
});
