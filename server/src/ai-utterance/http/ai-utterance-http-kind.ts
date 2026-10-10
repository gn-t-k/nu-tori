import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { AiUtterance } from "../domain/ai-utterance";
import { aiUtteranceRecordSchema } from "./ai-utterance-record-schema";
import { toAiUtteranceRecord } from "./to-ai-utterance-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const aiUtteranceHttpKind: HttpRecordKind<
  AiUtterance,
  never,
  typeof aiUtteranceRecordSchema
> = {
  writes: undefined,
  recordSchema: aiUtteranceRecordSchema,
  toRecord: toAiUtteranceRecord,
};
