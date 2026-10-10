import type { z } from "@hono/zod-openapi";
import type { AiUtterance } from "../domain/ai-utterance";
import type { aiUtteranceRecordSchema } from "./ai-utterance-record-schema";

export const toAiUtteranceRecord = (
  value: AiUtterance,
): z.input<typeof aiUtteranceRecordSchema> => ({
  id: value.id,
  body: value.body,
  sentTextId: value.sentTextId,
  mealIds: value.mealIds,
});
