import type { RecordId } from "../../domain/record-id";
import type { AiUtterance } from "./ai-utterance";

export type AiUtteranceStore = {
  find: (id: RecordId) => AiUtterance | undefined;
};
