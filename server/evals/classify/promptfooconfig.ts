import type { UnifiedConfig } from "promptfoo";
import type { ClassificationErrorKind } from "./judge-classification-error/judge-classification-error";

// 読み分けの評価（#419 の「読み分け」、#423）。
// 評価の組を Claude Haiku 5.5 に読ませ、間違いの種類ごとの件数を namedScores に出す。
// 回し方と鍵は run-eval.ts
const config: Partial<UnifiedConfig> = {
  description: "読み分けの評価（Claude Haiku 5.5）",
  prompts: ["{{text}}"],
  providers: [{ id: "file://haiku-provider.ts", label: "haiku" }],
  tests: "file://cases.json",
  defaultTest: {
    // 件数を数えるだけで、テストは落とさない
    assert: (["meal_as_chat", "chat_as_meal"] as const satisfies ClassificationErrorKind[]).map(
      (error) => ({
        type: "javascript" as const,
        value:
          "file://judge-classification-error/judge-classification-error.ts:judgeClassificationError",
        weight: 0,
        metric: error,
        config: { error },
      }),
    ),
  },
};

export default config;
