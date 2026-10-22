// 推定の予定を、予定の時刻の新しい順に並べる。
// 見送り・保留から足す予定は、見送った・保留した予定のあとに書くので、時刻が同じなら見送った・保留した予定を古いとする
export const sortSchedulesNewestFirst = <Schedule extends { dueAt: Date; progress: string }>(
  schedules: readonly Schedule[],
): Schedule[] =>
  schedules.toSorted(
    (a, b) =>
      b.dueAt.getTime() - a.dueAt.getTime() || Number(isSetAside(a)) - Number(isSetAside(b)),
  );

const isSetAside = ({ progress }: { progress: string }): boolean =>
  progress === "deferred" || progress === "held";
