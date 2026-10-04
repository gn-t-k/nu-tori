import { isTimeZoneName } from "./is-time-zone-name";
import type { LatestTimeZoneStore } from "./latest-time-zone-store";

// ユーザーの最新のタイムゾーン。控えは届いたままで、名前が読めないときは undefined
export const findLatestValidTimeZone = (store: LatestTimeZoneStore): string | undefined => {
  const timeZone = store.find();
  return timeZone !== undefined && isTimeZoneName(timeZone) ? timeZone : undefined;
};
