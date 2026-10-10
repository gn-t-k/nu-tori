import type { UnifiedConfig } from "promptfoo";
import { classificationMetricName } from "./classification-metric-name";
import { classificationThresholds } from "./classification-thresholds";

// 読み分けのモデルの比べ方（#419 の「読み分け」、#423）。評価の組を Jev と Claude Haiku 5.5 に読ませ、
// しきい値と間違いの種類ごとの件数を namedScores に出す。表と決めたもの、回し方と鍵は summarize-classification-results.ts
const config: Partial<UnifiedConfig> = {
  description: "読み分けのモデルの比べ方（Jev と Claude Haiku 5.5）",
  prompts: ["{{text}}"],
  providers: [
    { id: "file://jev-provider.ts", label: "jev" },
    { id: "file://haiku-provider.ts", label: "haiku" },
  ],
  tests: "file://cases.json",
  defaultTest: {
    // 件数を数えるだけで、テストは落とさない。Haiku 5.5 の答えはしきい値に関わらず同じ数になる
    assert: classificationThresholds.flatMap((threshold) =>
      (["meal_as_chat", "chat_as_meal"] as const).map((error) => ({
        type: "javascript" as const,
        value:
          "file://judge-classification-error/judge-classification-error.ts:judgeClassificationError",
        weight: 0,
        metric: classificationMetricName(error, threshold),
        config: { threshold, error },
      })),
    ),
  },
};

export default config;
