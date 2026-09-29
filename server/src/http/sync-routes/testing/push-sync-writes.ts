import { env } from "cloudflare:workers";
import { app } from "../../app";
import { createSyncClientState } from "./create-sync-client-state";

export const pushSyncWrites = (
  sessionToken: string,
  body: { writes: unknown[]; isFinalBatch?: boolean; clientState?: Record<string, unknown> },
) =>
  app.request(
    "/v1/sync/writes",
    {
      method: "POST",
      headers: { authorization: `Bearer ${sessionToken}`, "content-type": "application/json" },
      body: JSON.stringify({
        writes: body.writes,
        isFinalBatch: body.isFinalBatch ?? false,
        clientState: createSyncClientState(body.clientState),
      }),
    },
    env,
  );
