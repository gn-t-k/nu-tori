import { runDurableObjectAlarm, runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { getAccountDurableObject } from "../../durable-object/get-account-durable-object";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import {
  mockPhotosBucketDeleteError,
  mockPhotosBucketPutError,
} from "../../meal/durable-object/testing/photos-bucket.mock";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { enableUsageEventSending } from "../sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { signInTestAccount } from "../testing";
import { createPhotoBytes } from "./testing/create-photo-bytes";
import { fetchMealPhoto } from "./testing/fetch-meal-photo";
import { putMealPhoto } from "./testing/put-meal-photo";
import { beforeEach, describe, expect, test, vi } from "vitest";

describe("食事の写真", () => {
  let accountId: string;
  let sessionToken: string;
  let pullStatusChanges: (afterSequence: number) => Promise<PullResult["changes"]>;
  let readPhotoFile: (photoId: string) => Promise<R2Object | null>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    pullStatusChanges = async (afterSequence) => {
      const pulled = await (
        await pullSyncChanges(sessionToken, { afterSequence })
      ).json<PullResult>();
      return pulled.changes.filter(({ kind }) => kind === "meal_estimation_status");
    };
    readPhotoFile = (photoId) => env.PHOTOS.head(`${accountId}/meal-photos/${photoId}`);
  });

  describe("写真を送ったとき", () => {
    let photoId: string;
    let photo: Uint8Array;
    let response: Response;
    beforeEach(async () => {
      photoId = generateRecordId();
      photo = createPhotoBytes();
      response = await putMealPhoto(sessionToken, photoId, {
        body: photo,
        contentType: "image/jpeg",
      });
    });

    test("受け取ったと応えること", () => {
      expect(response.status).toBe(204);
    });

    test("R2 の、アカウントの写真の控えの接頭辞の下に置くこと", async () => {
      expect(await readPhotoFile(photoId)).not.toBeNull();
    });

    test("縮小版を取りに行くと、送った中身が返ること", async () => {
      const fetched = await fetchMealPhoto(sessionToken, photoId);
      expect({
        status: fetched.status,
        contentType: fetched.headers.get("content-type"),
        body: new Uint8Array(await fetched.arrayBuffer()),
      }).toEqual({ status: 200, contentType: "image/jpeg", body: photo });
    });
  });

  describe("食事の写真が2枚あり、1枚だけ届いたとき", () => {
    let mealId: string;
    let sequenceBeforePhoto: number;
    beforeEach(async () => {
      mealId = generateRecordId();
      const [firstPhotoId, secondPhotoId] = [generateRecordId(), generateRecordId()];
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { id: mealId, photos: [{ id: firstPhotoId }, { id: secondPhotoId }] },
          }),
        ],
      });
      ({ nextAfterSequence: sequenceBeforePhoto } = await (
        await pullSyncChanges(sessionToken)
      ).json<PullResult>());
      await putMealPhoto(sessionToken, firstPhotoId);
    });

    test("推定の状態を変えないこと", async () => {
      expect(await pullStatusChanges(sequenceBeforePhoto)).toEqual([]);
    });

    test("推定の予定に入れないこと", async () => {
      expect(await readRows(accountId, "SELECT * FROM estimation_schedules")).toEqual([]);
    });
  });

  describe("食事の写真の最後の1枚が届いたとき", () => {
    let mealId: string;
    let sequenceBeforePhoto: number;
    let receivedAfter: number;
    let receivedBefore: number;
    beforeEach(async () => {
      mealId = generateRecordId();
      const [firstPhotoId, secondPhotoId] = [generateRecordId(), generateRecordId()];
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: {
              id: mealId,
              sentTimeZone: "Pacific/Kiritimati",
              photos: [{ id: firstPhotoId }, { id: secondPhotoId }],
            },
          }),
        ],
        clientState: { timeZone: "Pacific/Kiritimati" },
      });
      await putMealPhoto(sessionToken, firstPhotoId);
      // 最新の同期の要求のタイムゾーンは、食事を送ったときと1日ずれる
      ({ nextAfterSequence: sequenceBeforePhoto } = await (
        await pullSyncChanges(sessionToken, { clientState: { timeZone: "Pacific/Pago_Pago" } })
      ).json<PullResult>());
      receivedAfter = Date.now();
      await putMealPhoto(sessionToken, secondPhotoId);
      receivedBefore = Date.now();
    });

    test("取りに行くと、推定中に変わったことが返ること", async () => {
      expect(await pullStatusChanges(sequenceBeforePhoto)).toEqual([
        {
          sequence: expect.any(Number),
          kind: "meal_estimation_status",
          recordId: mealId,
          record: { mealId, status: "estimating" },
        },
      ]);
    });

    test("数える日を、最新の同期の要求のタイムゾーンでの、受け取った日にすること", async () => {
      const rows = await readRows(accountId, "SELECT counted_on FROM estimation_schedules");
      expect([
        formatDay(receivedAfter, "Pacific/Pago_Pago"),
        formatDay(receivedBefore, "Pacific/Pago_Pago"),
      ]).toContain(rows[0]?.["counted_on"]);
    });
  });

  describe("最新の同期の要求のタイムゾーンが読めない名前のとき、食事の写真がそろったら", () => {
    let receivedAfter: number;
    let receivedBefore: number;
    beforeEach(async () => {
      const photoId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { sentTimeZone: "Pacific/Kiritimati", photos: [{ id: photoId }] },
          }),
        ],
        clientState: { timeZone: "Not/A_Zone" },
      });
      receivedAfter = Date.now();
      await putMealPhoto(sessionToken, photoId);
      receivedBefore = Date.now();
    });

    test("数える日を、食事を送ったときのタイムゾーンで決めること", async () => {
      const rows = await readRows(accountId, "SELECT counted_on FROM estimation_schedules");
      expect([
        formatDay(receivedAfter, "Pacific/Kiritimati"),
        formatDay(receivedBefore, "Pacific/Kiritimati"),
      ]).toContain(rows[0]?.["counted_on"]);
    });
  });

  describe("同じ写真が二度届いたとき", () => {
    let photoId: string;
    let responses: Response[];
    beforeEach(async () => {
      photoId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { photos: [{ id: photoId }] } })],
      });
      responses = [
        await putMealPhoto(sessionToken, photoId),
        await putMealPhoto(sessionToken, photoId),
      ];
    });

    test("どちらも受け取ったと応えること", () => {
      expect(responses.map(({ status }) => status)).toEqual([204, 204]);
    });

    test("受け取りを1つだけ控えること", async () => {
      const rows = await readRows(accountId, "SELECT meal_photo_id FROM meal_photo_file_receipts");
      expect(rows).toEqual([{ meal_photo_id: photoId }]);
    });

    test("推定の予定を1つだけ入れること", async () => {
      expect(await readRows(accountId, "SELECT id FROM estimation_schedules")).toHaveLength(1);
    });
  });

  describe("写真が食事より先に届き、そのあと食事が届いたとき", () => {
    let mealId: string;
    beforeEach(async () => {
      mealId = generateRecordId();
      const photoId = generateRecordId();
      await putMealPhoto(sessionToken, photoId);
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
      });
    });

    test("取りに行くと、推定中が返ること", async () => {
      expect(await pullStatusChanges(0)).toEqual([
        {
          sequence: expect.any(Number),
          kind: "meal_estimation_status",
          recordId: mealId,
          record: { mealId, status: "estimating" },
        },
      ]);
    });

    test("推定の予定を1つ入れること", async () => {
      expect(await readRows(accountId, "SELECT id FROM estimation_schedules")).toHaveLength(1);
    });
  });

  describe("食事を消したあとに、その食事の写真が届いたとき", () => {
    let photoId: string;
    let response: Response;
    beforeEach(async () => {
      photoId = generateRecordId();
      const mealId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } }),
          deleteMealWrite(mealId),
        ],
      });
      response = await putMealPhoto(sessionToken, photoId);
    });

    test("受け取ったと応えること", () => {
      expect(response.status).toBe(204);
    });

    test("R2 に置かないこと", async () => {
      expect(await readPhotoFile(photoId)).toBeNull();
    });

    test("受け取りを控えないこと", async () => {
      expect(await readRows(accountId, "SELECT * FROM meal_photo_file_receipts")).toEqual([]);
    });
  });

  describe("受け付けなかった作る書き込みの写真が、あとから届いたとき", () => {
    let photoId: string;
    beforeEach(async () => {
      photoId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { entryMethod: "typed", photos: [{ id: photoId }] } })],
      });
      await putMealPhoto(sessionToken, photoId);
    });

    test("R2 に置かないこと", async () => {
      expect(await readPhotoFile(photoId)).toBeNull();
    });
  });

  describe("JPEG でないものを送ったとき", () => {
    let photoId: string;
    let response: Response;
    beforeEach(async () => {
      photoId = generateRecordId();
      response = await putMealPhoto(sessionToken, photoId, {
        body: createPhotoBytes(),
        contentType: "image/png",
      });
    });

    test("415 を返すこと", () => {
      expect(response.status).toBe(415);
    });

    test("R2 に置かないこと", async () => {
      expect(await readPhotoFile(photoId)).toBeNull();
    });
  });

  describe("3 MiB を超える写真を送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await putMealPhoto(sessionToken, generateRecordId(), {
        body: new Uint8Array(3 * 1024 * 1024 + 1),
        contentType: "image/jpeg",
      });
    });

    test("413 を返すこと", () => {
      expect(response.status).toBe(413);
    });
  });

  describe("R2 に置けなかったとき", () => {
    let photoId: string;
    let response: Response;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      photoId = generateRecordId();
      await enableUsageEventSending(accountId);
      captureSpy = mockPostHogCaptureEndpointOk();
      mockPhotosBucketPutError(new Error("R2 に届かない"));
      logSpy = vi.spyOn(console, "log");
      response = await putMealPhoto(sessionToken, photoId);
    });

    test("送り直せるよう、500 を返すこと", () => {
      expect(response.status).toBe(500);
    });

    test("受け取りを控えないこと", async () => {
      expect(await readRows(accountId, "SELECT * FROM meal_photo_file_receipts")).toEqual([]);
    });

    test("写真の受け取りの失敗を、失敗した段とともに PostHog に送ること", () => {
      expect(readPostHogCapturedEvents(captureSpy)).toEqual([
        {
          event: "meal_photo_receipt_failed",
          distinct_id: accountId,
          properties: { stage: "put_file", $geoip_disable: true },
        },
      ]);
    });

    test("要求ごとのログに、失敗した段を出すこと", () => {
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          route: "PUT /v1/meal-photos/:photoId",
          status: 500,
          failedStage: "put_file",
        }),
      );
    });
  });

  describe("縮小版を取りに行ったとき", () => {
    describe("まだ受け取っていない写真のとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await fetchMealPhoto(sessionToken, generateRecordId());
      });

      test("404 を返すこと", () => {
        expect(response.status).toBe(404);
      });
    });

    describe("消した食事の写真で、R2 からまだ消していないとき", () => {
      let photoId: string;
      let response: Response;
      beforeEach(async () => {
        photoId = generateRecordId();
        const mealId = generateRecordId();
        await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
        });
        await putMealPhoto(sessionToken, photoId);
        await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
        response = await fetchMealPhoto(sessionToken, photoId);
      });

      test("404 を返すこと", () => {
        expect(response.status).toBe(404);
      });
    });

    describe("ほかのアカウントの写真のとき", () => {
      let response: Response;
      beforeEach(async () => {
        const photoId = generateRecordId();
        await putMealPhoto(sessionToken, photoId);
        const other = await signInTestAccount(generateRecordId());
        response = await fetchMealPhoto(other.sessionToken, photoId);
      });

      test("404 を返すこと", () => {
        expect(response.status).toBe(404);
      });
    });
  });

  describe("受け取った写真の食事を消したとき", () => {
    let photoId: string;
    beforeEach(async () => {
      photoId = generateRecordId();
      const mealId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
      });
      await putMealPhoto(sessionToken, photoId);
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
      // 張ったアラームは、テストの実行環境でもひとりでに動く
      await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
    });

    test("アラームで R2 から写真の控えを消すこと", async () => {
      await vi.waitFor(async () => {
        expect(await readPhotoFile(photoId)).toBeNull();
      });
    });

    test("R2 から消した事実を控えること", async () => {
      await vi.waitFor(async () => {
        const rows = await readRows(
          accountId,
          "SELECT meal_photo_id FROM meal_photo_file_deletions",
        );
        expect(rows).toEqual([{ meal_photo_id: photoId }]);
      });
    });
  });

  describe("R2 から消せないあいだに、受け取った写真の食事を消したとき", () => {
    let photoId: string;
    let deleteSpy: ReturnType<typeof mockPhotosBucketDeleteError>;
    let alarmFailure: unknown;
    beforeEach(async () => {
      // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
      useFakeClock(Date.now() + 86_400_000);
      photoId = generateRecordId();
      const mealId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
      });
      await putMealPhoto(sessionToken, photoId);
      deleteSpy = mockPhotosBucketDeleteError(new Error("R2 に届かない"));
      await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
      alarmFailure = await runDurableObjectAlarm(getAccountDurableObject(env, accountId)).then(
        () => undefined,
        (error: unknown) => error,
      );
    });

    test("R2 から消した事実を控えないこと", async () => {
      expect(await readRows(accountId, "SELECT * FROM meal_photo_file_deletions")).toEqual([]);
    });

    test("Cloudflare のアラームのやり直しに任せるよう、アラームから例外を投げること", () => {
      expect(alarmFailure).toEqual(expect.objectContaining({ message: "R2 に届かない" }));
    });

    test("消し直しのために、アラームを今に張り直さないこと", async () => {
      expect(
        await runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
          state.storage.getAlarm(),
        ),
      ).toBeNull();
    });

    describe("そのあと R2 に届くようになり、送る要求が届いたとき", () => {
      beforeEach(async () => {
        deleteSpy.mockRestore();
        await pushSyncWrites(sessionToken, { writes: [createWeightRecordWrite()] });
        await runDurableObjectAlarm(getAccountDurableObject(env, accountId));
      });

      test("アラームで R2 から消し直すこと", async () => {
        expect(await readPhotoFile(photoId)).toBeNull();
      });
    });
  });
});

// 受け取った時刻の前後の日を、テストの中で同じ設定で整形して比べる（en-CA は YYYY-MM-DD）
const formatDay = (instant: number, timeZone: string) =>
  new Intl.DateTimeFormat("en-CA", { timeZone }).format(instant);
