import { env } from "cloudflare:workers";
import { app } from "../../app";
import { createSyncClientState } from "./create-sync-client-state";

export const pullSyncChanges = (
  sessionToken: string,
  query: { afterSequence?: number; clientState?: Record<string, unknown> } = {},
) => {
  const params = new URLSearchParams(
    Object.entries({
      ...createSyncClientState(query.clientState),
      afterSequence: query.afterSequence ?? 0,
    }).flatMap(([key, value]) => (value === undefined ? [] : [[key, String(value)]])),
  );
  return app.request(
    `/v1/sync/changes?${params.toString()}`,
    { headers: { authorization: `Bearer ${sessionToken}` } },
    env,
  );
};

export type PullResult = {
  changes: { sequence: number; kind: string; recordId: string; record: Record<string, unknown> }[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | null;
};
