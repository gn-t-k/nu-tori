import type { RecordId } from "../../domain/record-id";

export type SentTextStatusStore = {
  // 読み分けの今の結果。まだ読み分けていなければ undefined
  findClassification: (sentTextId: RecordId) => "meal" | "conversation" | undefined;
};
