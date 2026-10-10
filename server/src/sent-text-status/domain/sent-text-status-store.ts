import type { RecordId } from "../../domain/record-id";
import type { ReplyFailureReason } from "./sent-text-status";

export type SentTextStatusStore = {
  // 読み分けの今の結果。まだ読み分けていなければ undefined
  findClassification: (sentTextId: RecordId) => "meal" | "conversation" | undefined;
  // 文章の返事の依頼ごとの、依頼から先の出来事
  findReplyRequestProgresses: (sentTextId: RecordId) => ReplyRequestProgress[];
};

// 返事の依頼から先の出来事。回数切れと作れなかったは、終えた時刻を持つ（最後に終わった依頼を決めるため。設計判断 38）
export type ReplyRequestProgress =
  | { progress: "waiting" | "generating" | "replied" }
  | { progress: "halted"; endedAt: Date }
  | { progress: "abandoned"; endedAt: Date; reason: ReplyFailureReason };
