// 続いている出来事（推定・返事の生成）の、次に試みを書いて提供元を呼ぶ時刻。最後の試みの時刻と試みの数から出す。
// 最後の試みを始めた時刻から、15 秒を試みごとに倍に広げて待つ（6回やり直して約 16 分）。
// 結果の無い試みは呼び出し中かもしれないので、時間の上限（timeLimitMs）が過ぎるまでは途中で止まったとみなさない
export const computeNextAttemptAt = (
  attempts: readonly { attemptedAt: Date; ended: unknown }[],
  timeLimitMs: number,
): Date => {
  const last = attempts.at(-1);
  if (last === undefined) {
    throw new Error("試みの無い出来事は無い（始めることと最初の試みは同じトランザクションで書く）");
  }
  const waitMs = 15_000 * 2 ** (attempts.length - 1);
  return new Date(
    last.attemptedAt.getTime() + (last.ended === undefined ? timeLimitMs : 0) + waitMs,
  );
};
