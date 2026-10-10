import type { RecordId } from "../../domain/record-id";
import type { AiUtterance } from "./ai-utterance";

export type AiUtteranceStore = {
  find: (id: RecordId) => AiUtterance | undefined;
  // 文章への返事（文章から見た返事は 0 か 1）
  findOfSentText: (sentTextId: RecordId) => AiUtterance | undefined;
};
