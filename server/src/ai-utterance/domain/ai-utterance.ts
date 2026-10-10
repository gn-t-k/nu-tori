import type { RecordId } from "../../domain/record-id";

// 返事（AI の発言）。ID は返事の生成の ID。時刻とタイムゾーンは応える送った文章のものを使う
export type AiUtterance = {
  id: RecordId;
  body: string;
  // 応える送った文章
  sentTextId: RecordId;
  // 指し示す食事。並びが返事の中の並び。食事が消えても残る
  mealIds: RecordId[];
};
