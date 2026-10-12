import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { AiUtterance } from "./ai-utterance";
import type { AiUtteranceStore } from "./ai-utterance-store";

// 返事の種類。サーバーだけが書き、消す操作は無いので消えない
export const createAiUtteranceKind = (
  store: AiUtteranceStore,
): RecordKind<"ai_utterance", never, AiUtterance> =>
  createServerOnlyKind({ name: "ai_utterance", whenGone: "never", find: store.find });
