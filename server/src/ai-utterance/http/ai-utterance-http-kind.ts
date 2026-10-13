import { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { AiUtterance } from "../domain/ai-utterance";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const aiUtteranceRecordSchema = z
  .object({
    id: z.string().openapi({ description: "返事の生成の ID（見守る要求の最初に流す ID と同じ）" }),
    body: z.string(),
    sentTextId: z.string().openapi({
      description: "応える送った文章の ID。時刻とタイムゾーンはこの文章のものを使う",
    }),
    mealIds: z.array(z.string()).openapi({
      description: "指し示す食事の ID。並びが返事の中の並び。食事が消えても残る",
    }),
  })
  .openapi({
    description: "kind が ai_utterance の変更の record。返事は消えない",
  });

export const aiUtteranceHttpKind: HttpRecordKind<
  AiUtterance,
  never,
  typeof aiUtteranceRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: aiUtteranceRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    body: value.body,
    sentTextId: value.sentTextId,
    mealIds: value.mealIds,
  }),
};
