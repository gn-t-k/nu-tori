import type { RecordId } from "../../domain/record-id";
import type { DailyGuide } from "./daily-guide";

export type DailyGuideStore = {
  find: (id: RecordId) => DailyGuide | undefined;
};
