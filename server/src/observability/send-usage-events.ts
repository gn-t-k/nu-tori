import { match } from "ts-pattern";
import type { UsageEvent } from "../domain/usage-event";

// Durable Object では応答のあとに続ける仕組みが効かないので、数秒の上限を付けて待つ。失敗も時間切れも握りつぶす
export const sendUsageEvents = async (
  env: { POSTHOG_PROJECT_TOKEN?: string },
  accountId: string,
  events: readonly UsageEvent[],
): Promise<void> => {
  if (env.POSTHOG_PROJECT_TOKEN === undefined || events.length === 0) {
    return;
  }
  try {
    await fetch("https://eu.i.posthog.com/batch/", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        api_key: env.POSTHOG_PROJECT_TOKEN,
        batch: events.map((event) => toCapturedEvent(accountId, event)),
      }),
      signal: AbortSignal.timeout(3000),
    });
  } catch {
    return;
  }
};

const toCapturedEvent = (accountId: string, event: UsageEvent) => {
  const { name, properties } = match(event)
    .with({ name: "sync_write_rejected" }, (rejected) => ({
      name: rejected.name,
      properties: {
        write_kind: rejected.writeKind,
        record_type: rejected.recordType,
        reason: rejected.reason,
      },
    }))
    .with({ name: "sync_pending_writes_reported" }, (reported) => ({
      name: reported.name,
      properties: {
        pending_write_count: reported.pendingWriteCount,
        oldest_pending_write_age_seconds: reported.oldestPendingWriteAgeSeconds,
      },
    }))
    .exhaustive();
  return {
    event: name,
    distinct_id: accountId,
    properties: { ...properties, $geoip_disable: true },
  };
};
