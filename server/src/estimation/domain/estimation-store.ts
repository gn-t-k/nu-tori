import type { EstimationAttemptConclusion } from "./estimation-attempt-conclusion";

// 推定・試み・結果・完了・断念を読み書きする置き場。どれも INSERT だけで持つ
export type EstimationStore = {
  // 予定から推定を始める。同じ予定から二度始めないことは、表の一意で守る
  insertEstimation: (estimation: { id: string; scheduleId: string; startedAt: Date }) => void;
  // 数える日の推定の数。食事を消しても減らない
  countEstimationsCountedOn: (countedOn: string) => number;
  // 提供元を呼ぶ前に書く
  insertAttempt: (attempt: { id: string; estimationId: string; attemptedAt: Date }) => void;
  // 続いている推定（完了も断念も無く、食事につながっている）と、その試みを古い順に
  findContinuingEstimations: () => {
    estimationId: string;
    mealId: string;
    attempts: EstimationAttempt[];
  }[];
  // 推定の対象の食事。呼び出し中に食事が消えて、つなぎが無ければ undefined
  findMealIdOfEstimation: (estimationId: string) => string | undefined;
  // 食事の、始めていて完了も断念もしていない推定
  findOngoingEstimationIdOfMeal: (mealId: string) => string | undefined;
  findAttempts: (estimationId: string) => EstimationAttempt[];
  insertAttemptResult: (attemptResult: {
    attemptId: string;
    endedAt: Date;
    conclusion: EstimationAttemptConclusion;
  }) => void;
  insertCompletion: (completion: {
    estimationId: string;
    completedAt: Date;
    result: "estimated" | "no_dishes";
  }) => void;
  insertAbandonment: (abandonment: { estimationId: string; abandonedAt: Date }) => void;
};

// 結果の無い試みは、呼び出し中か、途中で止まった試み
export type EstimationAttempt = {
  attemptedAt: Date;
  ended: { endedAt: Date; conclusion: EstimationAttemptConclusion } | undefined;
};
