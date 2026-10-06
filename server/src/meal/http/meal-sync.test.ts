import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { countCorrectionsByReceivedOrder } from "../../http/sync-routes/testing/count-corrections-by-received-order";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { inspectDeletedContents } from "../../dish/http/testing/inspect-deleted-contents";
import { recordMealWithCorrectedDish } from "../../dish/http/testing/record-meal-with-corrected-dish";
import { countEstimations } from "../../estimation/http/testing/count-estimations";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { recordPhotographedMeal } from "../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { createMealWrite } from "./testing/create-meal-write";
import { deleteMealWrite } from "./testing/delete-meal-write";
import { updateMealWrite } from "./testing/update-meal-write";
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

    describe("同じ ID で、範囲の外の作る書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId, photos: [] } })],
        });
      });

      test("範囲を確かめる前に、同じ ID の食事として捨てること", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
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

    describe("消した食事の ID で、範囲の外の作る書き込みを送ったとき", () => {
      let recreateResponse: Response;
      beforeEach(async () => {
        recreateResponse = await pushSyncWrites(sessionToken, {
          writes: [createMealWrite({ meal: { id: mealId, photos: [] } })],
        });
      });

      test("範囲を確かめる前に、削除の印で捨てること", async () => {
        expect((await recreateResponse.json<PushResults>()).results[0]?.result).toBe(
          "ignored_tombstone",
        );
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

  describe("食事があるとき", () => {
    let mealId: string;
    let created: ReturnType<typeof createMealWrite>;
    let afterCreated: number;
    beforeEach(async () => {
      mealId = crypto.randomUUID();
      created = createMealWrite({ meal: { id: mealId, eatenAt: Date.UTC(2026, 8, 30, 3, 0) } });
      await pushSyncWrites(sessionToken, { writes: [created] });
      afterCreated = (await (await pullSyncChanges(sessionToken)).json<PullResult>())
        .nextAfterSequence;
    });

    describe("時刻を直す書き込みを送ったとき", () => {
      let write: ReturnType<typeof updateMealWrite>;
      let response: Response;
      beforeEach(async () => {
        write = updateMealWrite(mealId, Date.UTC(2026, 8, 30, 4, 30));
        response = await pushSyncWrites(sessionToken, { writes: [write] });
      });

      test("当てたと書き込みごとの結果を返すこと", async () => {
        expect({ status: response.status, body: await response.json() }).toEqual({
          status: 200,
          body: { results: [{ writeId: write.id, result: "applied" }] },
        });
      });

      test("前回の続きから取りに行くと、直した時刻の食事が返り、時差と送った時刻と入口は変わらないこと", async () => {
        const pulled = await (
          await pullSyncChanges(sessionToken, { afterSequence: afterCreated })
        ).json<PullResult>();
        expect(pulled.changes).toEqual([
          {
            sequence: expect.any(Number),
            kind: "meal",
            recordId: mealId,
            record: { ...created.meal, eatenAt: Date.UTC(2026, 8, 30, 4, 30) },
          },
        ]);
      });

      describe("もう一度、別の時刻に直したとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, {
            writes: [updateMealWrite(mealId, Date.UTC(2026, 8, 30, 2, 15))],
          });
        });

        test("取りに行くと、あとに受け取った時刻の食事が返ること", async () => {
          const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
          expect(pulled.changes.find(({ kind }) => kind === "meal")?.record["eatenAt"]).toBe(
            Date.UTC(2026, 8, 30, 2, 15),
          );
        });
      });
    });

    describe("今の時刻と同じ時刻に直す書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [updateMealWrite(mealId, Date.UTC(2026, 8, 30, 3, 0))],
        });
      });

      test("当てたと返すこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
      });

      test("前回の続きから取りに行っても、変更が無いこと", async () => {
        const pulled = await (
          await pullSyncChanges(sessionToken, { afterSequence: afterCreated })
        ).json<PullResult>();
        expect(pulled.changes).toEqual([]);
      });
    });

    describe("食事を消したあとに、時刻を直す書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(mealId)] });
        response = await pushSyncWrites(sessionToken, {
          writes: [updateMealWrite(mealId, Date.UTC(2026, 8, 30, 4, 30))],
        });
      });

      test("見つからないとして受け付けず、食事の削除の印を添えること", async () => {
        const [result] = (await response.json<PushResults>()).results;
        expect({
          result: result?.result,
          rejectionReason: result?.rejectionReason,
          current: result?.current,
        }).toEqual({
          result: "rejected",
          rejectionReason: "record_not_found",
          current: {
            status: "deleted",
            change: { kind: "meal_deletion", recordId: mealId, record: {} },
          },
        });
      });
    });
  });

  describe("知らない ID の食事の時刻を直す書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [updateMealWrite(crypto.randomUUID(), Date.UTC(2026, 8, 30, 4, 30))],
      });
    });

    test("見つからないとして受け付けず、食事が無いことを添えること", async () => {
      const [result] = (await response.json<PushResults>()).results;
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

  describe("推定できた食事の時刻を直す書き込みを送ったとき", () => {
    let mealId: string;
    let dishIds: string[];
    let pulled: PullResult;
    beforeEach(async () => {
      // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
      useFakeClock(Date.now() + 86_400_000);
      mockCreateEstimationProviderOk();
      mealId = await recordPhotographedMeal(sessionToken);
      await runEstimationAlarm(accountId);
      const estimated = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      dishIds = estimated.changes
        .filter(({ kind, record }) => kind === "dish" && record["version"] === 1)
        .map(({ recordId }) => recordId);
      if (dishIds.length === 0) {
        throw new Error("版が 1 の料理が無い");
      }
      await pushSyncWrites(sessionToken, {
        writes: [updateMealWrite(mealId, Date.UTC(2026, 8, 30, 4, 30))],
      });
      pulled = await (
        await pullSyncChanges(sessionToken, { afterSequence: estimated.nextAfterSequence })
      ).json<PullResult>();
    });

    test("前回の続きから取りに行くと、食事のあとに、その食事の料理すべてが版 2 で返ること", () => {
      expect(
        pulled.changes.map(({ kind, recordId, record }) => ({
          kind,
          recordId,
          version: record["version"],
        })),
      ).toEqual([
        { kind: "meal", recordId: mealId, version: undefined },
        ...dishIds.map((recordId) => ({ kind: "dish", recordId, version: 2 })),
      ]);
    });

    test("時刻の修正の行の控えに、受け取った順があること", async () => {
      expect(await countCorrectionsByReceivedOrder(accountId)).toEqual({
        meal_eaten_at_corrections: { withOrder: 1, withoutOrder: 0 },
        dish_name_corrections: { withOrder: 0, withoutOrder: 0 },
        dish_quantity_corrections: { withOrder: 0, withoutOrder: 0 },
        ingredient_quantity_corrections: { withOrder: 0, withoutOrder: 0 },
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

    describe("前の日の食事の時刻を直して日をまたぎ、直した日の食事を作る書き込みを送ったとき", () => {
      beforeEach(async () => {
        // 東京の 9月29日 12:00 を、9月30日 08:00 に直す
        const earlier = createMealWrite({
          meal: { eatenAt: Date.UTC(2026, 8, 29, 3, 0), eatenAtUtcOffsetSeconds: 32_400 },
        });
        await pushSyncWrites(sessionToken, {
          writes: [
            earlier,
            updateMealWrite(String(earlier.meal["id"]), Date.UTC(2026, 8, 29, 23, 0)),
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

      test("直した食事を数えて、その日の2回目として送ること", () => {
        expect(readPostHogCapturedEvents(fetchSpy)[0]?.properties["meal_count_of_day"]).toBe(2);
      });
    });

    describe("同じ日の食事の時刻を直して前の日に移し、その日の食事を作る書き込みを送ったとき", () => {
      beforeEach(async () => {
        // 東京の 9月30日 08:00 を、9月29日 12:00 に直す
        const earlier = createMealWrite({
          meal: { eatenAt: Date.UTC(2026, 8, 29, 23, 0), eatenAtUtcOffsetSeconds: 32_400 },
        });
        await pushSyncWrites(sessionToken, {
          writes: [
            earlier,
            updateMealWrite(String(earlier.meal["id"]), Date.UTC(2026, 8, 29, 3, 0)),
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

      test("前の日に移した食事を数えず、その日の1回目として送ること", () => {
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

  describe("写真の ID がとても多い作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: { photos: Array.from({ length: 300 }, () => ({ id: crypto.randomUUID() })) },
          }),
        ],
      });
    });

    test("要求ごと失敗せず、範囲の外として受け付けないこと", async () => {
      expect({
        status: response.status,
        reason: (await response.json<PushResults>()).results[0]?.rejectionReason,
      }).toEqual({ status: 200, reason: "out_of_range" });
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
  describe("時刻と料理の名前と量と材料を直し、推定し直しで材料が置き換わり、待つ予定を取り消した料理と、直していない料理を持つ食事を消す書き込みを送ったとき", () => {
    let mealId: string;
    let dishIds: string[];
    let ingredientIds: string[];
    let estimationCountsBefore: Awaited<ReturnType<typeof countEstimations>>;
    let estimationCountsAfter: Awaited<ReturnType<typeof countEstimations>>;
    let write: ReturnType<typeof deleteMealWrite>;
    let inspected: Awaited<ReturnType<typeof inspectDeletedContents>>;
    beforeEach(async () => {
      // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
      useFakeClock(Date.now() + 86_400_000);
      mockCreateEstimationProviderOk();
      const prepared = await recordMealWithCorrectedDish(accountId, sessionToken);
      mealId = prepared.mealId;
      dishIds = [prepared.dishId, prepared.untouchedDishId];
      ingredientIds = [...prepared.ingredientIds, ...prepared.untouchedIngredientIds];
      estimationCountsBefore = await countEstimations(accountId);
      write = deleteMealWrite(mealId);
      await pushSyncWrites(sessionToken, { writes: [write] });
      inspected = await inspectDeletedContents(accountId, {
        mealIds: [mealId],
        dishIds,
        ingredientIds,
      });
      estimationCountsAfter = await countEstimations(accountId);
    });

    test("控えを外部キーで指す表のうち、削除の印と帳簿のほかに、消した食事・料理・材料の控えから辿れる行が残らないこと", () => {
      expect({
        // 数え上げが修正の表を拾っていること
        countsCorrectionTables: [
          "meal_eaten_at_corrections",
          "dish_name_corrections",
          "dish_quantity_corrections",
          "ingredient_quantity_corrections",
          "estimation_schedule_cancellations",
        ].every((table) => inspected.tablesReferringToReceipts.includes(table)),
        leftoverRowsByTable: inspected.leftoverRowsByTable,
      }).toEqual({ countsCorrectionTables: true, leftoverRowsByTable: {} });
    });

    test("食事・料理・当てた推定・推定の量・材料・栄養・比例の明細・つなぎ・取り消しが残らないこと", () => {
      expect(inspected.contentCounts).toEqual({
        dishes: 0,
        estimationApplications: 0,
        estimatedQuantities: 0,
        ingredients: 0,
        ingredientNutrients: 0,
        foodCompositionIngredients: 0,
        proportions: 0,
        dishScheduleLinks: 0,
        cancellationsOfLinkedSchedules: 0,
        meals: 0,
      });
    });

    test("料理と、前の推定の材料も含むすべての材料の削除の印を、食事を消した書き込みの控えつきで書くこと", () => {
      const receipt = { kind: "delete", recordType: "meal", recordId: mealId };
      expect({
        dishes: inspected.dishDeletionReceipts,
        ingredients: inspected.ingredientDeletionReceipts,
      }).toEqual({
        dishes: Object.fromEntries(dishIds.map((id) => [id, receipt])),
        ingredients: Object.fromEntries(ingredientIds.map((id) => [id, receipt])),
      });
    });

    test("予定と推定は残ること", () => {
      expect(estimationCountsAfter).toEqual(estimationCountsBefore);
    });

    test("外部キーの違反が無いこと", () => {
      expect(inspected.foreignKeyViolations).toEqual([]);
    });
  });
});
