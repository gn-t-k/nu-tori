import type { RecordId } from "../../domain/record-id";
import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";
import type { EstimationTarget } from "./estimation-target";

// 推定・試み・結果・完了・断念を読む置き場。書くのは推定の書き込みの口（writeEstimationEvents）だけ
export type EstimationStore = {
  // 数える日の推定の数。食事を消しても減らない
  countEstimationsCountedOn: (countedOn: string) => number;
  // 続いている推定（完了も断念も無く、食事か料理につながっている）と、その試みを古い順に
  findContinuingEstimations: () => {
    estimationId: string;
    target: EstimationTarget;
    attempts: EstimationAttempt[];
  }[];
  // 推定の対象の食事か料理。呼び出し中に食事か料理が消えて、つなぎが無ければ undefined
  findTargetOfEstimation: (estimationId: string) => EstimationTarget | undefined;
  // 食事の、始めていて完了も断念もしていない推定
  findOngoingEstimationIdOfMeal: (mealId: RecordId) => string | undefined;
  findAttempts: (estimationId: string) => EstimationAttempt[];
};

// 結果の無い試みは、呼び出し中か、途中で止まった試み
export type EstimationAttempt = {
  attemptedAt: Date;
  ended: { endedAt: Date; conclusion: EstimationAttemptConclusion } | undefined;
};
