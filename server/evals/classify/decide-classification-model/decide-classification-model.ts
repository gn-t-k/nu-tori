// 評価の結果から、読み分けのモデルとしきい値を決める（#419 の「読み分け」の「Jev にする条件」）。
// 会話を食事にした間違い（記録を汚す）が 0 で、食事を会話にした間違い（記録を落とす。会話として送り直すでは拾えない）が
// Haiku 5.5 の数＋許す差以内のしきい値のうち、一番低いものにする。無ければ Haiku 5.5
export const decideClassificationModel = (input: {
  haiku: ErrorCounts;
  jev: (ErrorCounts & { threshold: number })[];
}): { model: "jev"; threshold: number } | { model: "haiku" } => {
  const mealAsChatLimit = input.haiku.mealAsChat + allowedExtraMealAsChat;
  const thresholds = input.jev
    .filter(({ chatAsMeal, mealAsChat }) => chatAsMeal === 0 && mealAsChat <= mealAsChatLimit)
    .map(({ threshold }) => threshold);
  return thresholds.length === 0
    ? { model: "haiku" }
    : { model: "jev", threshold: Math.min(...thresholds) };
};

type ErrorCounts = { mealAsChat: number; chatAsMeal: number };

// 評価の組（80 個）の 5%
const allowedExtraMealAsChat = 4;
