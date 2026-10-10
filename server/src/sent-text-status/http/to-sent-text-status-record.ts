import type { z } from "@hono/zod-openapi";
import type { SentTextStatus } from "../domain/sent-text-status";
import type { sentTextStatusRecordSchema } from "./sent-text-status-record-schema";

export const toSentTextStatusRecord = (
  value: SentTextStatus,
  sentTextId: string,
): z.input<typeof sentTextStatusRecordSchema> => ({
  sentTextId,
  classification: value.classification,
});
