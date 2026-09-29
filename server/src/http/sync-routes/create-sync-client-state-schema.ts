import { z } from "@hono/zod-openapi";

// 送る要求は本文、取りに行く要求はクエリで受けるので、数の読み方だけを差し替えられるようにする
export const createSyncClientStateSchema = (readCount: z.ZodType<number>) =>
  z.object({
    deviceId: z.string().min(1),
    timeZone: z.string().min(1).openapi({
      description: "読めない名前でも、届いたまま控える",
      example: "Asia/Tokyo",
    }),
    appVersion: z.string().min(1),
    osVersion: z.string().min(1),
    pendingWriteCount: readCount,
    oldestPendingWriteAgeSeconds: readCount.optional().openapi({
      description: "秒。送り待ちが無いときは省く",
      param: { required: false },
    }),
    pendingPhotoCount: readCount,
  });
