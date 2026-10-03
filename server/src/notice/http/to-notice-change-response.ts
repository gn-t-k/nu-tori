import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { Notice } from "../domain/notice";
import type { noticeRecordSchema } from "./notice-record-schema";

export const toNoticeChangeResponse = (
  sequence: number,
  current: PresentRecord<Notice>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "notice",
      recordId,
      record: toNoticeRecord(value),
    }))
    // 知らせは削除の印を持たないので、読む口が deleted を返すことは無い
    .with({ status: "deleted" }, () => {
      throw new Error("知らせに削除の印は無い");
    })
    .exhaustive();

const toNoticeRecord = (notice: Notice): z.input<typeof noticeRecordSchema> => ({
  id: notice.id,
  noticeType: notice.noticeType,
  issuedAt: notice.issuedAt.getTime(),
  timeZone: notice.timeZone,
  targetOn: notice.targetOn,
  response:
    notice.response === undefined
      ? undefined
      : {
          respondedAt: notice.response.respondedAt.getTime(),
          timeZone: notice.response.timeZone,
        },
});
