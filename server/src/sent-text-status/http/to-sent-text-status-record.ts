import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { SentTextStatus } from "../domain/sent-text-status";
import type { sentTextStatusRecordSchema } from "./sent-text-status-record-schema";

export const toSentTextStatusRecord = (
  value: SentTextStatus,
  sentTextId: string,
): z.input<typeof sentTextStatusRecordSchema> => ({
  sentTextId,
  classification: value.classification,
  ...match(value.reply)
    .returnType<{ replyStatus: string; replyFailureReason?: string }>()
    .with({ type: "failed" }, ({ type, reason }) => ({
      replyStatus: type,
      replyFailureReason: reason,
    }))
    .with(
      { type: "none" },
      { type: "awaiting" },
      { type: "replied" },
      { type: "halted" },
      ({ type }) => ({
        replyStatus: type,
      }),
    )
    .exhaustive(),
});
