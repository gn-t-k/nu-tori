import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SyncWrite } from "../../domain/sync-write";
import type { sentTextWriteSchemas } from "./sent-text-write-schemas";

export const toSentTextWrite = (write: z.infer<(typeof sentTextWriteSchemas)[number]>): SyncWrite =>
  match(write)
    .with({ type: "create_sent_text" }, ({ id, sentText }): SyncWrite => ({
      id,
      type: "create_sent_text",
      sentText: {
        id: sentText.id,
        body: sentText.body,
        sentAt: new Date(sentText.sentAt),
        timeZone: sentText.timeZone,
      },
    }))
    .with({ type: "resend_sent_text_as_conversation" }, ({ id, sentTextId }): SyncWrite => ({
      id,
      type: "resend_sent_text_as_conversation",
      sentTextId,
    }))
    .exhaustive();
