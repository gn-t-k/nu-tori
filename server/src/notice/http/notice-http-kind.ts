import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Notice } from "../domain/notice";
import { noticeRecordSchema } from "./notice-record-schema";
import { noticeWriteSchemas } from "./notice-write-schemas";
import { toNoticeRecord } from "./to-notice-record";
import { toNoticeWrite } from "./to-notice-write";

export const noticeHttpKind: HttpRecordKind<
  Notice,
  (typeof noticeWriteSchemas)[number],
  typeof noticeRecordSchema
> = {
  writes: { schemas: noticeWriteSchemas, toWrite: toNoticeWrite },
  recordSchema: noticeRecordSchema,
  toRecord: toNoticeRecord,
};
