import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { RecordKindStores } from "../../domain/record-kind-stores";

// サブスクリプションの区切りと今日を出すタイムゾーン。最新の読めるタイムゾーン、無ければ最初のサインインのタイムゾーン、それも無ければ UTC（課金の仕事のアラームの時刻と同じ選び方）
export const findSubscriptionTimeZone = (
  stores: Pick<RecordKindStores, "latestTimeZone" | "firstSignIn">,
): string =>
  findLatestValidTimeZone(stores.latestTimeZone) ?? stores.firstSignIn.findTimeZone() ?? "UTC";
