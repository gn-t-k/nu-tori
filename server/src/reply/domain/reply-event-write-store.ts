import type { RecordId } from "../../domain/record-id";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyRequest } from "./reply-request";

// 返事の流れの出来事（依頼・きっかけ・回数切れ・生成・試み・結果・返事・作れなかった）を書く置き場。どれも INSERT だけで持つ。
// 返事の書き込みの口（writeReplyEvents）にだけ渡し、ほかは読みだけの置き場で読む
export type ReplyEventWriteStore = {
  // 依頼と、きっかけのサブセット1つを書く
  insertRequest: (request: ReplyRequest) => void;
  insertHalt: (halt: { requestId: string; haltedAt: Date }) => void;
  insertGeneration: (generation: { id: RecordId; requestId: string; startedAt: Date }) => void;
  insertAttempt: (attempt: { id: string; generationId: RecordId; attemptedAt: Date }) => void;
  // 提供元のエラーと 400 なら、エラーの種類も書く
  insertAttemptResult: (attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: ReplyAttemptConclusion;
  }) => void;
  // 返事と、指し示す食事を渡した順の並びで書く
  insertUtterance: (utterance: {
    generationId: RecordId;
    body: string;
    mealIds: readonly RecordId[];
  }) => void;
  insertAbandonment: (abandonment: { generationId: RecordId; abandonedAt: Date }) => void;
  // 口が決まりを確かめるための読み出し
  findSentTextIdOfRequest: (requestId: string) => RecordId | undefined;
  findSentTextIdOfGeneration: (generationId: RecordId) => RecordId | undefined;
  hasGeneration: (requestId: string) => boolean;
  hasHalt: (requestId: string) => boolean;
  hasUtterance: (generationId: RecordId) => boolean;
  hasAbandonment: (generationId: RecordId) => boolean;
};
