import type { z } from "@hono/zod-openapi";
import type { UsualWeighingTime } from "../domain/usual-weighing-time";
import type { usualWeighingTimeRecordSchema } from "./usual-weighing-time-record-schema";

export const toUsualWeighingTimeRecord = (
  value: UsualWeighingTime,
): z.input<typeof usualWeighingTimeRecordSchema> => ({ minuteOfDay: value.minuteOfDay });
