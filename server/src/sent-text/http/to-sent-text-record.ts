import type { z } from "@hono/zod-openapi";
import type { SentText } from "../domain/sent-text";
import type { sentTextRecordSchema } from "./sent-text-record-schema";

export const toSentTextRecord = (value: SentText): z.input<typeof sentTextRecordSchema> => ({
  id: value.id,
  body: value.body,
  sentAt: value.sentAt.getTime(),
  timeZone: value.timeZone,
});
