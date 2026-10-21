import { generateRecordId } from "../record-id";
import { computeCalendarDayInTimeZone } from "../compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../is-time-zone-name";
import type { RecordChangeWriter } from "../record-change-writer";
import type { FirstSignInStore } from "./first-sign-in-store";

// 使い始めた日は一度決めたら変えない。タイムゾーンが届かないか読めないときは UTC の日付にする。
// サブスクリプションの状態の記録の ID は最初のサインインの ID なので、同じトランザクションで状態の変更を足す
export const recordFirstSignIn = (
  writeRecordChanges: RecordChangeWriter,
  store: FirstSignInStore,
  signIn: { signedInAt: Date; timeZone: string | undefined },
): void => {
  writeRecordChanges(({ addChange }) => {
    if (store.exists()) {
      return;
    }
    const timeZone =
      signIn.timeZone !== undefined && isTimeZoneName(signIn.timeZone)
        ? signIn.timeZone
        : undefined;
    const id = generateRecordId();
    store.insert({
      id,
      startedOn: computeCalendarDayInTimeZone(signIn.signedInAt, timeZone ?? "UTC"),
      signedInAt: signIn.signedInAt,
      timeZone,
    });
    addChange({ recordType: "subscription_status", recordId: id });
  });
};
