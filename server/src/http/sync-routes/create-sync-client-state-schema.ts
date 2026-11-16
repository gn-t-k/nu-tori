import { z } from "@hono/zod-openapi";
import { recordIdSchema } from "../../domain/record-id";

// 要求ごとのログに控える文字列の長さの上限。IANA 名でいちばん長いものは 32 字で、版は「1.0.0」「26.0.1」のように短い
const maximumTimeZoneLength = 64;
const maximumVersionLength = 32;

// 送る要求は本文、取りに行く要求はクエリで受けるので、数の読み方だけを差し替えられるようにする
export const createSyncClientStateSchema = (readCount: z.ZodType<number>) =>
  z.object({
    deviceId: recordIdSchema,
    timeZone: z.string().min(1).max(maximumTimeZoneLength).openapi({
      description: "読めない名前でも、届いたまま控える",
      example: "Asia/Tokyo",
    }),
    appVersion: z.string().min(1).max(maximumVersionLength),
    osVersion: z.string().min(1).max(maximumVersionLength),
    pendingWriteCount: readCount,
    oldestPendingWriteAgeSeconds: readCount.optional().openapi({ param: { required: false } }),
    pendingPhotoCount: readCount,
  });
