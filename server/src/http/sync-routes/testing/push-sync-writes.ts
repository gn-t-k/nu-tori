import { env } from "cloudflare:workers";
import { app } from "../../app";
import { createSyncClientState } from "./create-sync-client-state";

export const pushSyncWrites = (
  sessionToken: string,
  body: { writes: unknown[]; isFinalBatch?: boolean; clientState?: Record<string, unknown> },
  headers: Record<string, string> = {},
) =>
  app.request(
    "/v1/sync/writes",
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${sessionToken}`,
        "content-type": "application/json",
        ...headers,
      },
      body: JSON.stringify({
        writes: body.writes,
        isFinalBatch: body.isFinalBatch ?? false,
        clientState: createSyncClientState(body.clientState),
      }),
    },
    env,
  );

export type PushResults = {
  results: {
    writeId: string;
    result: string;
    rejectionReason?: string;
    current?: {
      status: string;
      change?: { kind: string; recordId: string; record: Record<string, unknown> };
    };
  }[];
};
