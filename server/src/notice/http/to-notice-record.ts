import type { z } from "@hono/zod-openapi";
import type { Notice } from "../domain/notice";
import type { noticeRecordSchema } from "./notice-record-schema";

export const toNoticeRecord = (value: Notice): z.input<typeof noticeRecordSchema> => ({
  id: value.id,
  noticeType: value.noticeType,
  issuedAt: value.issuedAt.getTime(),
  timeZone: value.timeZone,
  targetOn: value.targetOn,
  response:
    value.response === undefined
      ? undefined
      : { respondedAt: value.response.respondedAt.getTime(), timeZone: value.response.timeZone },
});
