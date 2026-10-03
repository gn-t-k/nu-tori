import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { noticeWriteSchemas } from "./notice-write-schemas";

export const toNoticeWrite = (write: z.infer<(typeof noticeWriteSchemas)[number]>): SyncWrite =>
  match(write)
    .with({ type: "create_notice" }, ({ id, notice }): SyncWrite => ({
      id,
      type: "create_notice",
      notice: {
        id: notice.id,
        noticeType: notice.noticeType,
        issuedAt: new Date(notice.issuedAt),
        timeZone: notice.timeZone,
        targetOn: notice.targetOn,
      },
    }))
    .with({ type: "respond_notice" }, ({ id, noticeId, response }): SyncWrite => ({
      id,
      type: "respond_notice",
      noticeId,
      response: { respondedAt: new Date(response.respondedAt), timeZone: response.timeZone },
    }))
    .exhaustive();
