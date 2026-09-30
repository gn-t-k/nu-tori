import type { CurrentRecord } from "./current-record";

export type PresentRecord<TValue> = Exclude<CurrentRecord<TValue>, { status: "absent" }>;
