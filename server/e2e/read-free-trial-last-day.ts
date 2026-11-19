import { z } from "zod";
import type { DeviceSession } from "./device-client";

// サブスクリプションの状態の記録から、無料体験の最後の日を読む。無料体験が無ければ undefined。
// テストユーザーは無料体験によらず使えるので、確かめに使えない
export const readFreeTrialLastDay = async (session: DeviceSession): Promise<string | undefined> => {
  const record = (await session.pullAllChanges())
    .filter(({ kind }) => kind === "subscription_status")
    .at(-1)?.record;
  if (record === undefined) {
    throw new Error("サブスクリプションの状態の記録が、取りに行く応答に無い");
  }
  const status = z
    .discriminatedUnion("type", [
      z.object({ type: z.literal("test_user") }),
      z.object({
        type: z.literal("regular"),
        freeTrial: z.object({ type: z.string(), lastDay: z.string().optional() }),
      }),
    ])
    .parse(record);
  if (status.type === "test_user") {
    throw new Error("サインインしたアカウントがテストユーザーになっている");
  }
  return status.freeTrial.lastDay;
};
