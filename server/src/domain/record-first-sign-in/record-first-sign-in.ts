import { computeCalendarDay } from "../compute-calendar-day";
import { isTimeZoneName } from "../is-time-zone-name";
import type { FirstSignInStore } from "./first-sign-in-store";

// 使い始めた日は一度決めたら変えない。タイムゾーンが届かないか読めないときは UTC の日付にする
export const recordFirstSignIn = (
  store: FirstSignInStore,
  signIn: { signedInAt: Date; timeZone: string | undefined },
): void => {
  if (store.exists()) {
    return;
  }
  const timeZone =
    signIn.timeZone !== undefined && isTimeZoneName(signIn.timeZone) ? signIn.timeZone : undefined;
  store.insert({
    id: crypto.randomUUID(),
    startedOn: computeCalendarDay(signIn.signedInAt, timeZone ?? "UTC"),
    signedInAt: signIn.signedInAt,
    timeZone,
  });
};
