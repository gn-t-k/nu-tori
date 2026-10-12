// アラームで動かす仕事。進め方と、次に動く時刻の出し方を対で持つ。
// 並び（`account-alarm-jobs.ts`）に足すと、アラーム1回分の流れと、次に張る時刻の計算の両方に入る
export type AlarmJob<Stores, Deps, Report> = {
  advance: (stores: Stores, deps: Deps) => Promise<AlarmJobOutcome<Report>>;
  // この仕事が次に動く時刻。動かすものが無ければ undefined
  computeNextAt: (stores: Stores, now: Date) => Date | undefined;
};

type AlarmJobOutcome<Report> = { report: Report } & (
  | { result: "advanced" }
  // 途中で止まった。この仕事の次の時刻も入れて、並びから出した時刻に張り直す
  | { result: "stopped"; error: unknown }
  // 失敗した。この仕事の時刻には張り直さず、Cloudflare のアラームのやり直しに任せる
  | { result: "left_to_alarm_retry"; error: unknown }
);
