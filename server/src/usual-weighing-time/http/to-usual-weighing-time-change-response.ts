import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { UsualWeighingTime } from "../domain/usual-weighing-time";
import type { usualWeighingTimeRecordSchema } from "./usual-weighing-time-record-schema";

export const toUsualWeighingTimeChangeResponse = (
  sequence: number,
  current: PresentRecord<UsualWeighingTime>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "usual_weighing_time",
      recordId,
      record: {
        minuteOfDay: value.minuteOfDay,
      } satisfies z.input<typeof usualWeighingTimeRecordSchema>,
    }))
    .with({ status: "deleted" }, () => {
      throw new Error("いつもの時刻は削除の印を持たない");
    })
    .exhaustive();
