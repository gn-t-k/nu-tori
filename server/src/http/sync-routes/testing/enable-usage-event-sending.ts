import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { onTestFinished } from "vitest";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// テストは開発用の設定で動き、PostHog のトークンは本番にしか無い。env はすべての Durable Object で共有されるので、テストが終わったら戻す
export const enableUsageEventSending = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (instance) => {
    const durableObjectEnv = Reflect.get(instance, "env");
    Object.assign(durableObjectEnv, { POSTHOG_PROJECT_TOKEN: "phc_test" });
    onTestFinished(() => {
      Reflect.deleteProperty(durableObjectEnv, "POSTHOG_PROJECT_TOKEN");
    });
  });
