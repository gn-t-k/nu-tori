import type { RecordId } from "../../domain/record-id";
import type { SentText } from "./sent-text";

export type SentTextStore = {
  find: (id: RecordId) => SentText | undefined;
  insert: (sentText: SentText) => void;
};
