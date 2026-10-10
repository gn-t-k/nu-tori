import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { AiUtterance } from "./ai-utterance";
import type { AiUtteranceStore } from "./ai-utterance-store";

// 返事の種類。サーバーだけが書き、消す操作は無いので消えない
export const createAiUtteranceKind = (
  store: AiUtteranceStore,
): RecordKind<"ai_utterance", never, AiUtterance> => ({
  name: "ai_utterance",
  writes: undefined,
  follows: undefined,
  whenGone: "never",
  readCurrent: (recordId): CurrentRecord<AiUtterance> => {
    const aiUtterance = store.find(recordId);
    return aiUtterance === undefined
      ? { status: "absent" }
      : { status: "value", value: aiUtterance };
  },
});
