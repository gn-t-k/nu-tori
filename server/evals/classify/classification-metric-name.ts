import type { ClassificationErrorKind } from "./judge-classification-error/judge-classification-error";

// promptfoo の結果の namedScores で、しきい値と間違いの種類ごとの件数を引く名前（例: meal_as_chat_050）
export const classificationMetricName = (
  error: ClassificationErrorKind,
  threshold: number,
): string => `${error}_${String(Math.round(threshold * 100)).padStart(3, "0")}`;
