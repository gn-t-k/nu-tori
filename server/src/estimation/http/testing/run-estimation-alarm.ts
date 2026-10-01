import { runDurableObjectAlarm } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 張ってあるアラームをいま動かし、終わるまで待つ。張っていなければ false
export const runEstimationAlarm = (accountId: string) =>
  runDurableObjectAlarm(getAccountDurableObject(env, accountId));
