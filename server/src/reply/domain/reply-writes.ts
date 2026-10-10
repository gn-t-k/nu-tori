import type { RecordId } from "../../domain/record-id";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyRequest } from "./reply-request";

// 返事の流れの書き込み。返事の書き込みの口（writeReplyEvents）が、書く関数にだけ渡す。
// 口は、表で守らない決まり（設計判断 34・40）を書く前に確かめ、破る書き込みは投げる（呼び出し側のトランザクションごと戻る）
export type ReplyWrites = {
  // 依頼ときっかけのサブセットを一緒に書く。会話と読み分けた文章にだけ書ける
  request: (request: ReplyRequest) => void;
  // 回数切れ。生成を始めた依頼には書けない
  halt: (halt: { requestId: string; haltedAt: Date }) => void;
  // 生成を始める。回数切れの依頼には書けない。ID は返事の ID を兼ねる
  beginGeneration: (generation: { id: RecordId; requestId: string; startedAt: Date }) => void;
  // 提供元を呼ぶ前に書く
  beginAttempt: (attempt: { id: string; generationId: RecordId; attemptedAt: Date }) => void;
  recordAttemptResult: (attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: ReplyAttemptConclusion;
  }) => void;
  // 返事と指し示す食事（並びは渡した順）を書く。作れなかった生成には書けない
  reply: (reply: { generationId: RecordId; body: string; mealIds: readonly RecordId[] }) => void;
  // 作れなかった。返事を書いた生成には書けない
  abandon: (abandonment: { generationId: RecordId; abandonedAt: Date }) => void;
};
