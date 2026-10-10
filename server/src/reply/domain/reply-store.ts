import type { RecordId } from "../../domain/record-id";
import type { SentText } from "../../sent-text/domain/sent-text";
import type { ReplyAttempt } from "./reply-attempt";

// 返事の流れを読む置き場。書くのは返事の書き込みの口（writeReplyEvents）だけ
export type ReplyStore = {
  // 回数切れでも生成を始めてもいない依頼（応える文章の送った時刻の順）。
  // requestedAt は依頼を作った時刻（きっかけの時刻。読み分けなら読み分けた時刻）
  findWaitingRequests: () => {
    requestId: RecordId;
    sentText: SentText;
    countedOn: string;
    requestedAt: Date;
  }[];
  // 数える日の返事の生成の数。回数切れは生成でないので数えない
  countGenerationsCountedOn: (countedOn: string) => number;
  // 返事も作れなかったも無い生成と、その試み（試みの時刻の順）
  findContinuingGenerations: () => (ReplyGenerationOrigin & { attempts: ReplyAttempt[] })[];
  // 文章の、返事も作れなかったも無い生成（文章に 0 か 1。終わっていない依頼は1つまでなので）
  findContinuingGenerationId: (sentTextId: RecordId) => RecordId | undefined;
  // 生成の試み（試みの時刻の順）
  findAttempts: (generationId: RecordId) => ReplyAttempt[];
  // 返事か作れなかったを書いた生成か
  hasEnded: (generationId: RecordId) => boolean;
  // 文章に返事の依頼があるか（文脈の窓で、ユーザーの発言かを決める。設計判断 39）
  hasRequest: (sentTextId: RecordId) => boolean;
};

// 生成と、応える文章と依頼の時刻
export type ReplyGenerationOrigin = {
  generationId: RecordId;
  sentText: SentText;
  requestedAt: Date;
};
