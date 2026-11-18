import { z } from "zod";
import type { DeviceSession } from "./device-client";
import { computeCalendarDayInTimeZone } from "../src/domain/compute-calendar-day-in-time-zone";

// 無料体験の終わったアカウントを作るとき、使い始めたことにする日の前の日数。
// 課金を入れた日（開発用の BILLING_STARTED_ON）が30日より前なら、無料体験が終わる
export const expiredAccountAgeDays = 60;

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

// expiredAccountAgeDays 日前に使い始めたことにしたアカウントの無料体験が終わっていなければ、課金を入れた日を直すよう書いて投げる
export const requireFreeTrialEnded = async (session: DeviceSession): Promise<void> => {
  const freeTrialLastDay = await readFreeTrialLastDay(session);
  if (freeTrialLastDay === undefined || freeTrialLastDay >= computeTodayOfStartedOn()) {
    throw new Error(
      `${expiredAccountAgeDays}日前に使い始めたことにしても、無料体験が終わっていない（開発用の BILLING_STARTED_ON を30日より前の日にする。最後の日: ${freeTrialLastDay ?? "なし"}）`,
    );
  }
};

// 確かめのサインインはタイムゾーンを送らないので、使い始めた日と無料体験の最後の日は UTC の日付で数えられる
export const computeTodayOfStartedOn = (): string =>
  computeCalendarDayInTimeZone(new Date(), "UTC");
