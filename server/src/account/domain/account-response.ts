import type { UsageEvent } from "../../domain/usage-event";

// アカウントの口の答え。Durable Object は nextAlarmAt に張り、usageEvents を送り、result を返す
export type AccountResponse<Result> = {
  result: Result;
  // 張り直すものが無ければ undefined（今のアラームをそのままにする）
  nextAlarmAt: Date | undefined;
  // 送るかどうかを決めたあとの出来事。利用状況を送らない人には空
  usageEvents: UsageEvent[];
};
