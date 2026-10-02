import type { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Notice } from "../domain/notice";
import { noticeWriteTypes } from "../domain/notice-write";
import type { noticeWriteSchemas } from "./notice-write-schemas";
import { toNoticeChangeResponse } from "./to-notice-change-response";
import { toNoticeWrite } from "./to-notice-write";

export const noticeHttpKind: HttpRecordKind<
  Notice,
  z.infer<(typeof noticeWriteSchemas)[number]>
> = {
  writeTypes: noticeWriteTypes,
  toWrite: toNoticeWrite,
  toChangeResponse: toNoticeChangeResponse,
};
