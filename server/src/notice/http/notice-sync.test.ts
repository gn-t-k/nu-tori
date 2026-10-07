import { generateRecordId } from "../../domain/record-id";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { signInTestAccount } from "../../http/testing";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { createWeightRecordWrite } from "../../weight-record/http/testing/create-weight-record-write";
import { sourceDeletedWeightRecordWrite } from "../../weight-record/http/testing/source-deleted-weight-record-write";
import { createNoticeWrite } from "./testing/create-notice-write";
import { respondNoticeWrite } from "./testing/respond-notice-write";
import { beforeEach, describe, expect, test } from "vitest";

describe("知らせの同期", () => {
  let sessionToken: string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ sessionToken } = await signInTestAccount(generateRecordId()));
  });

  describe("体重の記録忘れの知らせを作る書き込みを送ったとき", () => {
    let write: ReturnType<typeof createNoticeWrite>;
    let response: Response;
    beforeEach(async () => {
      write = createNoticeWrite({
        notice: {
          issuedAt: 1_767_225_600_000,
          timeZone: "Asia/Tokyo",
          targetOn: "2026-01-01",
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

    test("取りに行くと、答えの無い知らせが返ること", async () => {
      const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
      expect(pulled.changes).toEqual([
        {
          sequence: expect.any(Number),
          kind: "notice",
          recordId: write.notice["id"],
          record: {
            id: write.notice["id"],
            noticeType: "missed_weight_record",
            issuedAt: 1_767_225_600_000,
            timeZone: "Asia/Tokyo",
            targetOn: "2026-01-01",
          },
        },
      ]);
    });
  });

  describe("同じ ID の知らせがすでにあるとき", () => {
    let existing: ReturnType<typeof createNoticeWrite>;
    beforeEach(async () => {
      existing = createNoticeWrite({ notice: { issuedAt: 1_767_225_600_000 } });
      await pushSyncWrites(sessionToken, { writes: [existing] });
    });

    describe("2台目から、同じ知らせの ID で作る書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [
            createNoticeWrite({
              notice: { id: existing.notice["id"], issuedAt: 1_767_229_200_000 },
            }),
          ],
        });
      });

      test("捨てること", async () => {
        expect((await response.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
      });

      test("先の知らせの値を変えないこと", async () => {
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(pulled.changes.map(({ record }) => record["issuedAt"])).toEqual([1_767_225_600_000]);
      });
    });
  });

  describe("受け付けない作る書き込みを送ったとき", () => {
    describe("知らない種類のとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createNoticeWrite({ notice: { noticeType: "missed_meal_record" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]).toEqual(
          expect.objectContaining({ result: "rejected", rejectionReason: "invalid_notice_type" }),
        );
      });

      test("知らせを残さないこと", async () => {
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(pulled.changes).toEqual([]);
      });
    });

    describe("IANA の名前として読めないタイムゾーンのとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createNoticeWrite({ notice: { timeZone: "Mars/Olympus" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]).toEqual(
          expect.objectContaining({ result: "rejected", rejectionReason: "invalid_time_zone" }),
        );
      });
    });

    describe("時差の形のタイムゾーンのとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createNoticeWrite({ notice: { timeZone: "+09:00" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]).toEqual(
          expect.objectContaining({ result: "rejected", rejectionReason: "invalid_time_zone" }),
        );
      });
    });

    describe("日付の形でない対象の日付のとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createNoticeWrite({ notice: { targetOn: "2026/01/01" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]).toEqual(
          expect.objectContaining({ result: "rejected", rejectionReason: "invalid_target_on" }),
        );
      });
    });

    describe("暦に無い対象の日付のとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [createNoticeWrite({ notice: { targetOn: "2026-02-30" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]).toEqual(
          expect.objectContaining({ result: "rejected", rejectionReason: "invalid_target_on" }),
        );
      });
    });
  });

  describe("ID が種類と日付からの v5 でない作る書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [createNoticeWrite({ notice: { id: generateRecordId() } })],
      });
    });

    test("当てること", async () => {
      expect((await response.json<PushResults>()).results[0]?.result).toBe("applied");
    });
  });

  describe("知らせがあるとき", () => {
    let noticeId: string;
    let created: PullResult;
    beforeEach(async () => {
      const create = createNoticeWrite();
      noticeId = String(create.notice["id"]);
      await pushSyncWrites(sessionToken, { writes: [create] });
      created = await (await pullSyncChanges(sessionToken)).json<PullResult>();
    });

    describe("答える書き込みを送ったとき", () => {
      let write: ReturnType<typeof respondNoticeWrite>;
      let response: Response;
      beforeEach(async () => {
        write = respondNoticeWrite(noticeId, {
          response: { respondedAt: 1_767_229_200_000, timeZone: "America/Los_Angeles" },
        });
        response = await pushSyncWrites(sessionToken, { writes: [write] });
      });

      test("当てたと書き込みごとの結果を返すこと", async () => {
        expect((await response.json<PushResults>()).results).toEqual([
          { writeId: write.id, result: "applied" },
        ]);
      });

      test("前回の続きから取りに行くと、答えた時刻とタイムゾーンを添えた知らせが返ること", async () => {
        const pulled = await (
          await pullSyncChanges(sessionToken, { afterSequence: created.nextAfterSequence })
        ).json<PullResult>();
        expect(pulled.changes).toEqual([
          {
            sequence: expect.any(Number),
            kind: "notice",
            recordId: noticeId,
            record: {
              id: noticeId,
              noticeType: "missed_weight_record",
              issuedAt: 1_767_225_600_000,
              timeZone: "Asia/Tokyo",
              targetOn: "2026-01-01",
              response: { respondedAt: 1_767_229_200_000, timeZone: "America/Los_Angeles" },
            },
          },
        ]);
      });

      describe("2台目から、同じ知らせに答える書き込みを送ったとき", () => {
        let second: Response;
        beforeEach(async () => {
          second = await pushSyncWrites(sessionToken, {
            writes: [
              respondNoticeWrite(noticeId, { response: { respondedAt: 1_767_232_800_000 } }),
            ],
          });
        });

        test("捨てること", async () => {
          expect((await second.json<PushResults>()).results[0]?.result).toBe("ignored_duplicate");
        });

        test("先の答えが残ること", async () => {
          const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
          expect(pulled.changes.map(({ record }) => record["response"])).toEqual([
            { respondedAt: 1_767_229_200_000, timeZone: "America/Los_Angeles" },
          ]);
        });
      });

      describe("2台目から、答えた知らせを作る書き込みを送ったとき", () => {
        beforeEach(async () => {
          await pushSyncWrites(sessionToken, {
            writes: [createNoticeWrite({ notice: { id: noticeId } })],
          });
        });

        test("答えていない形に戻らないこと", async () => {
          const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
          expect(pulled.changes.map(({ record }) => record["response"])).toEqual([
            { respondedAt: 1_767_229_200_000, timeZone: "America/Los_Angeles" },
          ]);
        });
      });
    });

    describe("体重記録を作って答えたあとに、その体重記録が消えたとき", () => {
      beforeEach(async () => {
        const weightRecord = createWeightRecordWrite();
        await pushSyncWrites(sessionToken, {
          writes: [weightRecord, respondNoticeWrite(noticeId)],
        });
        await pushSyncWrites(sessionToken, {
          writes: [sourceDeletedWeightRecordWrite(String(weightRecord.weightRecord["id"]))],
        });
      });

      test("答えが残ること", async () => {
        const pulled = await (await pullSyncChanges(sessionToken)).json<PullResult>();
        expect(
          pulled.changes
            .filter(({ kind }) => kind === "notice")
            .map(({ record }) => record["response"]),
        ).toEqual([{ respondedAt: 1_767_229_200_000, timeZone: "Asia/Tokyo" }]);
      });
    });

    describe("IANA の名前として読めないタイムゾーンで答える書き込みを送ったとき", () => {
      let response: Response;
      beforeEach(async () => {
        response = await pushSyncWrites(sessionToken, {
          writes: [respondNoticeWrite(noticeId, { response: { timeZone: "Mars/Olympus" } })],
        });
      });

      test("受け付けないこと", async () => {
        expect((await response.json<PushResults>()).results[0]?.rejectionReason).toBe(
          "invalid_time_zone",
        );
      });
    });
  });

  describe("知らせが無いときに答える書き込みを送ったとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await pushSyncWrites(sessionToken, {
        writes: [respondNoticeWrite(generateRecordId())],
      });
    });

    test("受け付けないこと", async () => {
      expect((await response.json<PushResults>()).results[0]).toEqual(
        expect.objectContaining({ result: "rejected", rejectionReason: "record_not_found" }),
      );
    });

    test("無いことを、今の値として添えること", async () => {
      expect((await response.json<PushResults>()).results[0]?.current).toEqual({
        status: "absent",
      });
    });
  });

  describe("答えのある知らせへの作る書き込みが受け付けられなかったとき", () => {
    let noticeId: string;
    let response: Response;
    beforeEach(async () => {
      const create = createNoticeWrite();
      noticeId = String(create.notice["id"]);
      await pushSyncWrites(sessionToken, { writes: [create, respondNoticeWrite(noticeId)] });
      response = await pushSyncWrites(sessionToken, {
        writes: [createNoticeWrite({ notice: { id: noticeId, timeZone: "Mars/Olympus" } })],
      });
    });

    test("その知らせの今の値を、取りに行く変更と同じ形で添えること", async () => {
      expect((await response.json<PushResults>()).results[0]?.current).toEqual({
        status: "value",
        change: {
          kind: "notice",
          recordId: noticeId,
          record: {
            id: noticeId,
            noticeType: "missed_weight_record",
            issuedAt: 1_767_225_600_000,
            timeZone: "Asia/Tokyo",
            targetOn: "2026-01-01",
            response: { respondedAt: 1_767_229_200_000, timeZone: "Asia/Tokyo" },
          },
        },
      });
    });
  });
});
