import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { WeightTrend } from "../domain/weight-trend";
import type { weightTrendRecordSchema } from "./weight-trend-record-schema";

export const toWeightTrendChangeResponse = (
  sequence: number,
  current: PresentRecord<WeightTrend>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "weight_trend",
      recordId,
      record: {
        days: value.map(({ calendarDay, trendKg }) => ({ calendarDay, trendKg })),
      } satisfies z.input<typeof weightTrendRecordSchema>,
    }))
    .with({ status: "deleted" }, () => {
      throw new Error("体重の傾向は削除の印を持たない");
    })
    .exhaustive();
