import { z } from "zod";
import { classificationMetricName } from "../classification-metric-name";
import { classificationThresholds } from "../classification-thresholds";

// promptfoo の結果（-o の JSON）から、Jev のしきい値ごとと Haiku 5.5 の、2種類の間違いの数を読む。
// 呼び出しに失敗した件があると数が欠けるので、数えずに失敗の数を返す（回し直す）。
// 結果の形やモデルの label が設定と食い違うのは設定の誤りなので throw する
export const readClassificationResults = (
  results: unknown,
):
  | {
      status: "complete";
      haiku: ErrorCounts;
      jev: (ErrorCounts & { threshold: number })[];
    }
  | { status: "incomplete"; errorCounts: { jev: number; haiku: number } } => {
  const { prompts } = resultsSchema.parse(results).results;
  const jev = findMetrics(prompts, "jev");
  const haiku = findMetrics(prompts, "haiku");
  if (jev.testErrorCount > 0 || haiku.testErrorCount > 0) {
    return {
      status: "incomplete",
      errorCounts: { jev: jev.testErrorCount, haiku: haiku.testErrorCount },
    };
  }
  return {
    status: "complete",
    // Haiku 5.5 の答えはしきい値に関わらず同じ数なので、一番低いしきい値の数を読む
    haiku: readErrorCounts(haiku.namedScores, classificationThresholds[0]),
    jev: classificationThresholds.map((threshold) => ({
      threshold,
      ...readErrorCounts(jev.namedScores, threshold),
    })),
  };
};

type ErrorCounts = { mealAsChat: number; chatAsMeal: number };

const resultsSchema = z.object({
  results: z.object({
    prompts: z.array(
      z.object({
        provider: z.string(),
        metrics: z.object({
          testErrorCount: z.number(),
          namedScores: z.record(z.string(), z.number()),
        }),
      }),
    ),
  }),
});

type PromptMetrics = z.infer<typeof resultsSchema>["results"]["prompts"][number]["metrics"];

const findMetrics = (
  prompts: z.infer<typeof resultsSchema>["results"]["prompts"],
  label: "jev" | "haiku",
): PromptMetrics => {
  const found = prompts.find(({ provider }) => provider === label);
  if (found === undefined) {
    throw new Error(`結果に ${label} の提供元が無い`);
  }
  return found.metrics;
};

const readErrorCounts = (namedScores: Record<string, number>, threshold: number): ErrorCounts => ({
  mealAsChat: readCount(namedScores, classificationMetricName("meal_as_chat", threshold)),
  chatAsMeal: readCount(namedScores, classificationMetricName("chat_as_meal", threshold)),
});

const readCount = (namedScores: Record<string, number>, name: string): number => {
  const count = namedScores[name];
  if (count === undefined) {
    throw new Error(`結果に ${name} の数が無い`);
  }
  return count;
};
