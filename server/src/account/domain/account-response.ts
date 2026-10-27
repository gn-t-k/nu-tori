import type { UsageEvent } from "../../domain/usage-event";

// アカウントの口の答え。Durable Object は usageEvents を利用状況の設定で絞って送り、result を返す。
// アラームは答えに載せず、Durable Object が要求のあとにいつも仕事の並びから張り直す
export type AccountResponse<Result> = {
  result: Result;
  // 起きた出来事。送るかどうか（利用状況の設定）は、Durable Object が送る前に1か所で決めるので、ここでは絞らない
  usageEvents: UsageEvent[];
};

// 要求ごとのログに足す値を持つ答え。Durable Object は result と一緒に受け口へ返し、受け口がログに出す
export type LoggedAccountResponse<Result> = AccountResponse<Result> & {
  requestLog: AccountRequestLog;
};

// 値（体重・kcal）は載せない
export type AccountRequestLog = {
  // 見直した週の数（見送りを含む）。まだ見直していない週を見なかった要求は undefined
  reviewedWeekCount: number | undefined;
};
