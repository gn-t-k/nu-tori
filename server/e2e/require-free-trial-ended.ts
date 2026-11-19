import type { DeviceSession } from "./device-client";
import { computeTodayOfStartedOn } from "./compute-today-of-started-on";
import { readFreeTrialLastDay } from "./read-free-trial-last-day";

// ageDays 日前に使い始めたことにしたアカウントの無料体験が終わっていなければ、課金を入れた日を直すよう書いて投げる
export const requireFreeTrialEnded = async (
  session: DeviceSession,
  ageDays: number,
): Promise<void> => {
  const freeTrialLastDay = await readFreeTrialLastDay(session);
  if (freeTrialLastDay === undefined || freeTrialLastDay >= computeTodayOfStartedOn()) {
    throw new Error(
      `${ageDays}日前に使い始めたことにしても、無料体験が終わっていない（開発用の BILLING_STARTED_ON を30日より前の日にする。最後の日: ${freeTrialLastDay ?? "なし"}）`,
    );
  }
};
