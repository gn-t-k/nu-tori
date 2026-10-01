import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { EstimationScheduleStore } from "./estimation-schedule-store";

// 数える日は、ユーザーの最新のタイムゾーンで決める。控えは届いたままで、名前が読めないときは undefined
export const findLatestValidTimeZone = (store: EstimationScheduleStore): string | undefined => {
  const timeZone = store.findLatestTimeZone();
  return timeZone !== undefined && isTimeZoneName(timeZone) ? timeZone : undefined;
};
