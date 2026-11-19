import { z } from "@hono/zod-openapi";
import { acceptedTimestampRange } from "../../domain/accepted-timestamp-range";

// 端末が書き込みで送る時刻。範囲の外は 400 で断る
export const timestampSchema = z
  .number()
  .int()
  .min(acceptedTimestampRange.minimum)
  .max(acceptedTimestampRange.maximum)
  .openapi({ description: "UNIX 時刻のミリ秒（UTC）" });
