import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { createMealWrite } from "./testing/create-meal-write";
import { deleteMealWrite } from "./testing/delete-meal-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("食事の同期", () => {
  let accountId: string;
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(crypto.randomUUID()));
  });

  describe("食事を作る書き込みを送ったとき", () => {
    let write: ReturnType<typeof createMealWrite>;
    let mealId: string;
    let photoIds: string[];
    let response: Response;
    beforeEach(async () => {
      mealId = crypto.randomUUID();
      photoIds = [crypto.randomUUID(), crypto.randomUUID()];
      write = createMealWrite({
        meal: {
          id: mealId,
          eatenAt: 1_790_000_000_000,
          eatenAtUtcOffsetSeconds: 19_800,
          sentAt: 1_790_000_600_000,
          sentTimeZone: "Asia/Tokyo",
          entryMethod: "picked",
          photos: photoIds.map((id) => ({ id })),
        },
      });
      response = await pushSyncWrites(sessionToken, { writes: [write] });
    });

    test("当てたと書き込みごとの結果を返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { results: [{ writeId: write.id, result: "applied" }] },
      });
    });

    test("取りに行くと、端末が送った値のまま食事と、写真を待っている推定の状態が返ること", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "meal",
          recordId: mealId,
          record: {
            id: mealId,
            eatenAt: 1_790_000_000_000,
            eatenAtUtcOffsetSeconds: 19_800,
            sentAt: 1_790_000_600_000,
            sentTimeZone: "Asia/Tokyo",
            entryMethod: "picked",
            photos: photoIds.map((id) => ({ id })),
          },
        },
        {
          sequence: expect.any(Number),
          kind: "meal_estimation_status",
          recordId: mealId,
          record: { mealId, status: "awaiting_photos" },
        },
      ]);
    });
  });

  describe("食事がすでにあるとき", () => {
    let existing: ReturnType<typeof createMealWrite>;
    let mealId: string;
    let photoId: string;
    beforeEach(async () => {
      mealId = crypto.randomUUID();
      photoId = crypto.randomUUID();
      existing = createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } });
      await pushSyncWrites(sessionToken, { writes: [existing] });
    });

    describe("別の書き込みの ID で、同じ ID の食事の作る書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { id: mealId, entryMethod: "picked", photos: [{ id: crypto.randomUUID() }] },
            }),
          ],
        });
      });

      test("捨てること", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
      });

      test("値を変えないこと", async () => {
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(pulled.changes[0]?.record).toEqual(existing.meal);
      });

      test("写真の削除の印を書かないこと", async () => {
        expect(await readRows(accountId, "SELECT * FROM meal_photo_deletions")).toEqual([]);
      });
    });

    describe("その食事の写真の ID と新しい写真の ID を持つ作る書き込みを、体重記録の書き込みと同じ要求で送ったとき", () => {
      let newPhotoId: string;
      let results: PushResults["results"];
      beforeEach(async () => {
        newPhotoId = crypto.randomUUID();
        const response = await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({ meal: { photos: [{ id: photoId }, { id: newPhotoId }] } }),
            createWeightRecordWrite(),
          ],
        });
        ({ results } = await response.json<PushResults>());
      });

      test("写真がもう使われているとして受け付けず、要求ごと戻さずにほかの書き込みを当てること", () => {
        expect(results.map(({ result, rejectionReason }) => ({ result, rejectionReason }))).toEqual(
          [
            { result: "rejected", rejectionReason: "photo_already_used" },
            { result: "applied", rejectionReason: undefined },
          ],
        );
      });

      test("宣言にも削除の印にもまだ無い写真の ID にだけ、写真の削除の印を書くこと", async () => {
        const rows = await readRows(accountId, "SELECT meal_photo_id FROM meal_photo_deletions");
        expect(rows).toEqual([{ meal_photo_id: newPhotoId }]);
      });
    });

    describe("同じ ID の食事の作る書き込みが範囲の外で受け付けられなかったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId, photos: [] } })],
        });
      });

      test("その食事の今の値を、取りに行く変更と同じ形で添えること", async () => {
        expect((await response.json<PushResults>()).results[0]?.current).toEqual({
          status: "value",
          change: { kind: "meal", recordId: mealId, record: existing.meal },
        });
      });
    });
  });

  describe("範囲の外の作る書き込みが受け付けられなかったとき", () => {
    let photoId: string;
    let response: Response;
    beforeEach(async () => {
      photoId = crypto.randomUUID();
      response = await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { eatenAtUtcOffsetSeconds: -43_260, photos: [{ id: photoId }] },
          }),
        ],
      });
    });

    test("食事が無いことを添えること", async () => {
      expect((await response.json<PushResults>()).results[0]?.current).toEqual({
        status: "absent",
      });
    });

    test("その写真の ID に写真の削除の印を書くこと", async () => {
      const rows = await readRows(accountId, "SELECT meal_photo_id FROM meal_photo_deletions");
      expect(rows).toEqual([{ meal_photo_id: photoId }]);
    });
  });

  describe("食事を消す書き込みを送ったとき", () => {
    let mealId: string;
    let photoIds: string[];
    let deletion: ReturnType<typeof deleteMealWrite>;
    let response: Response;
    let created: PullResult;
    beforeEach(async () => {
      mealId = crypto.randomUUID();
      photoIds = [crypto.randomUUID(), crypto.randomUUID()];
      await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { id: mealId, photos: photoIds.map((id) => ({ id })) } })],
      });
      created = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      deletion = deleteMealWrite(mealId);
      response = await pushSyncWrites(sessionToken, { writes: [deletion] });
    });

    test("消したと書き込みごとの結果を返すこと", async () => {
      expect({ status: response.status, body: await response.json() }).toEqual({
        status: 200,
        body: { results: [{ writeId: deletion.id, result: "applied" }] },
      });
    });

    test("前回の続きから取りに行くと、食事と推定の状態の削除の印が返ること", async () => {
      const pulled = await (
        await pullSyncChanges(sessionToken, { afterSequence: created.nextAfterSequence })
      ).json<PullResult>();
      expect(pulled.changes).toEqual([
        { sequence: expect.any(Number), kind: "meal_deletion", recordId: mealId, record: {} },
        {
          sequence: expect.any(Number),
          kind: "meal_estimation_status_deletion",
          recordId: mealId,
          record: {},
        },
      ]);
    });

    test("食事と写真の宣言の行を消し、写真の削除の印を残すこと", async () => {
      const rows = await readRows(
        accountId,
        `SELECT
           (SELECT COUNT(*) FROM meals) AS meals,
           (SELECT COUNT(*) FROM meal_photos) AS meal_photos,
           (SELECT COUNT(*) FROM meal_deletions) AS meal_deletions,
           (SELECT group_concat(meal_photo_id) FROM (SELECT meal_photo_id FROM meal_photo_deletions ORDER BY meal_photo_id)) AS meal_photo_deletions`,
      );
      expect(rows).toEqual([
        {
          meals: 0,
          meal_photos: 0,
          meal_deletions: 1,
          meal_photo_deletions: photoIds.toSorted().join(","),
        },
      ]);
    });

    describe("同じ書き込みを送り直したとき", () => {
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, { writes: [deletion] });
      });

      test("最初の結果を返すこと", async () => {
        expect((await response.json<PushResults>()).results).toEqual([
          { writeId: deletion.id, result: "applied" },
        ]);
      });
    });

    describe("別の書き込みで、同じ食事をもう一度消したとき", () => {
      let secondResponse: Response;
      let latest: PullResult;
      beforeEach(async () => {
        const afterFirstDeletion = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        secondResponse = await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
        latest = await (
          await pullSyncChanges(sessionToken, {
            afterSequence: afterFirstDeletion.nextAfterSequence,
          })
        ).json<PullResult>();
      });

      test("捨てること", async () => {
        expect((await secondResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
      });

      test("食事の削除の印を、次に取りに行った端末に返し直すこと", () => {
        expect(latest.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
          { kind: "meal_deletion", recordId: mealId },
        ]);
      });
    });

    describe("消した食事の ID の作る書き込みを送ったとき", () => {
      let recreateResponse: Response;
      beforeEach(async () => {
        recreateResponse = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId } })],
        });
      });

      test("捨てて、消えた食事を生き返らせないこと", async () => {
        expect((await recreateResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(pulled.changes.map(({ kind }) => kind)).toEqual([
          "meal_estimation_status_deletion",
          "meal_deletion",
        ]);
      });
    });

    describe("消した食事の写真の ID を持つ、別の食事の作る書き込みを送ったとき", () => {
      let recreateResponse: Response;
      beforeEach(async () => {
        recreateResponse = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { photos: [{ id: photoIds[0] }] } })],
        });
      });

      test("写真がもう使われているとして受け付けないこと", async () => {
        expect((await recreateResponse.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "photo_already_used",
        );
      });
    });
  });

  describe("知らない ID の食事を消す書き込みを送ったとき", () => {
    let mealId: string;
    let response: Response;
    beforeEach(async () => {
      mealId = crypto.randomUUID();
      response = await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
    });

    test("削除の印を残して受け付けること", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes.map(({ kind, recordId: id }) => ({ kind, recordId: id }))).toEqual([
        { kind: "meal_deletion", recordId: mealId },
        { kind: "meal_estimation_status_deletion", recordId: mealId },
      ]);
    });

    describe("あとから、その ID の作る書き込みが届いたとき", () => {
      let photoId: string;
      let createResponse: Response;
      beforeEach(async () => {
        photoId = crypto.randomUUID();
        createResponse = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
        });
      });

      test("捨てること", async () => {
        expect((await createResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
      });

      test("その写真の ID に写真の削除の印を書くこと", async () => {
        const rows = await readRows(accountId, "SELECT meal_photo_id FROM meal_photo_deletions");
        expect(rows).toEqual([{ meal_photo_id: photoId }]);
      });
    });
  });

  describe("本番のサーバーで", () => {
    let fetchSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      fetchSpy = mockPostHogCaptureEndpointOk();
    });

    describe("食事を作る書き込みを送ったとき", () => {
      let write: ReturnType<typeof createMealWrite>;
      beforeEach(async () => {
        write = createMealWrite({
          meal: {
            eatenAt: Date.UTC(2026, 8, 30, 3, 0),
            eatenAtUtcOffsetSeconds: 32_400,
            sentAt: Date.UTC(2026, 8, 30, 3, 25, 20),
            entryMethod: "picked",
          },
        });
        await pushSyncWrites(sessionToken, { writes: [write] });
      });

      test("入口と、撮った時刻から送った時刻までの分と、その日の何回目かを PostHog に送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
          {
            event: "meal_received",
            distinct_id: accountId,
            properties: {
              entry_method: "picked",
              minutes_from_eaten_to_sent: 25,
              meal_count_of_day: 1,
              $geoip_disable: true,
            },
          },
        ]);
      });

      describe("同じ書き込みを送り直したとき", () => {
        beforeEach(async () => {
          fetchSpy.mockClear();
          await pushSyncWrites(sessionToken, { writes: [write] });
        });

        test("もう一度は送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });

      describe("同じ食事の作る書き込みを、別の書き込みの ID でもう一度送ったとき", () => {
        beforeEach(async () => {
          fetchSpy.mockClear();
          await pushSyncWrites(sessionToken, {
            writes: [createMealWrite({ meal: { id: write.meal["id"] } })],
          });
        });

        test("もう一度は送らないこと", () => {
          expect(readPostHogCapturedEvents(fetchSpy)).toEqual([]);
        });
      });
    });

    describe("時差は違うが、食べた日が同じ食事があるとき", () => {
      beforeEach(async () => {
        // ロサンゼルスの 9月30日 13:00 と、東京の 9月30日 19:00
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { eatenAt: Date.UTC(2026, 8, 30, 20, 0), eatenAtUtcOffsetSeconds: -25_200 },
            }),
          ],
        });
        fetchSpy.mockClear();
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { eatenAt: Date.UTC(2026, 8, 30, 10, 0), eatenAtUtcOffsetSeconds: 32_400 },
            }),
          ],
        });
      });

      test("その日の2回目として送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)[0]?.properties["meal_count_of_day"]).toBe(2);
      });
    });

    describe("UTC の日付は同じだが、時差で出した食べた日が違う食事があるとき", () => {
      beforeEach(async () => {
        // 東京の 10月1日 01:00 と、東京の 9月30日 19:00
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { eatenAt: Date.UTC(2026, 8, 30, 16, 0), eatenAtUtcOffsetSeconds: 32_400 },
            }),
          ],
        });
        fetchSpy.mockClear();
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { eatenAt: Date.UTC(2026, 8, 30, 10, 0), eatenAtUtcOffsetSeconds: 32_400 },
            }),
          ],
        });
      });

      test("その日の1回目として送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)[0]?.properties["meal_count_of_day"]).toBe(1);
      });
    });

    describe("同じ食べた日の食事を消したあとに、食事を作る書き込みを送ったとき", () => {
      beforeEach(async () => {
        const earlier = createMealWrite({
          meal: { eatenAt: Date.UTC(2026, 8, 30, 3, 0), eatenAtUtcOffsetSeconds: 32_400 },
        });
        await pushSyncWrites(sessionToken, {
          writes: [earlier, deleteMealWrite(String(earlier.meal["id"]))],
        });
        fetchSpy.mockClear();
        await pushSyncWrites(sessionToken, {
          writes: [
            createMealWrite({
              meal: { eatenAt: Date.UTC(2026, 8, 30, 10, 0), eatenAtUtcOffsetSeconds: 32_400 },
            }),
          ],
        });
      });

      test("消した食事を数えないこと", () => {
        expect(readPostHogCapturedEvents(fetchSpy)[0]?.properties["meal_count_of_day"]).toBe(1);
      });
    });

    describe("受け付けなかった作る書き込みを送ったとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { photos: [] } })],
        });
      });

      test("食事を受け取った出来事を送らず、受け付けなかった種類と理由を送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)).toEqual([
          expect.objectContaining({
            event: "sync_write_rejected",
            properties: {
              write_kind: "create",
              record_type: "meal",
              reason: "out_of_range",
              $geoip_disable: true,
            },
          }),
        ]);
      });
    });
  });

  describe("使い始めた日より前に撮った食事の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { eatenAt: Date.UTC(2020, 0, 1) } })],
      });
    });

    test("受け付けること", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
    });
  });

  describe("写真の無い作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { photos: [] } })],
      });
    });

    test("範囲の外として受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe("out_of_range");
    });
  });

  describe("写真が5枚の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { photos: Array.from({ length: 5 }, () => ({ id: crypto.randomUUID() })) },
          }),
        ],
      });
    });

    test("範囲の外として受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe("out_of_range");
    });
  });

  describe("時差が +14:00 より東の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { eatenAtUtcOffsetSeconds: 50_460 } })],
      });
    });

    test("範囲の外として受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe("out_of_range");
    });
  });

  describe("入口が撮った・写真を選んだのどちらでもない作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { entryMethod: "typed" } })],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "invalid_entry_method",
      );
    });
  });

  describe("送ったときのタイムゾーンが IANA 名でなく時差の作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { sentTimeZone: "+09:00" } })],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "invalid_time_zone",
      );
    });
  });

  describe("同じ写真の ID を2つ持つ作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      const photoId = crypto.randomUUID();
      response = await pushSyncWrites(sessionToken, {
        writes: [createMealWrite({ meal: { photos: [{ id: photoId }, { id: photoId }] } })],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
        "duplicate_photo_ids",
      );
    });
  });
});
