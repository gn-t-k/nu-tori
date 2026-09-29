import type { z } from "@hono/zod-openapi";
import type { SyncClientState } from "../../domain/sync/sync-client-state";
import type { createSyncClientStateSchema } from "./create-sync-client-state-schema";

export const toSyncClientState = (
  clientState: z.infer<ReturnType<typeof createSyncClientStateSchema>>,
): SyncClientState => ({
  deviceId: clientState.deviceId,
  timeZone: clientState.timeZone,
  appVersion: clientState.appVersion,
  osVersion: clientState.osVersion,
  pendingWriteCount: clientState.pendingWriteCount,
  oldestPendingWriteAgeSeconds: clientState.oldestPendingWriteAgeSeconds,
  pendingPhotoCount: clientState.pendingPhotoCount,
});
