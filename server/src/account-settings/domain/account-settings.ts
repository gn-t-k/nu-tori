import type { RecordId } from "../../domain/record-id";

export type AccountSettings = {
  id: RecordId;
  sendsUsageData: boolean;
};
