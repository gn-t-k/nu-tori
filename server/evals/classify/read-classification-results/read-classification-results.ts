import { z } from "zod";
import type { ClassificationErrorKind } from "../judge-classification-error/judge-classification-error";

// promptfoo の結果（-o の JSON）から、Haiku 5.5 の2種類の間違いの数を読む。
// 呼び出しに失敗した件があると数が欠けるので、数えずに失敗の数と、失敗した文章ごとの理由（エラーの1行目。スタックを除く）を返す（回し直す）。
// 結果の形やモデルの label が設定と食い違うのは設定の誤りなので throw する
export const readClassificationResults = (
  results: unknown,
):
  | { status: "complete"; mealAsChat: number; chatAsMeal: number }
  | { status: "incomplete"; errorCount: number; failures: { text: string; reason: string }[] } => {
  const { prompts, results: rows } = resultsSchema.parse(results).results;
  const haiku = prompts.find(({ provider }) => provider === "haiku");
  if (haiku === undefined) {
    throw new Error("結果に haiku の提供元が無い");
  }
  const { testErrorCount, namedScores } = haiku.metrics;
  if (testErrorCount > 0) {
    const failures = rows.flatMap(({ vars, error }) =>
      error == null ? [] : [{ text: vars.text, reason: error.split("\n")[0] ?? "" }],
    );
    return { status: "incomplete", errorCount: testErrorCount, failures };
  }
  return {
    status: "complete",
    mealAsChat: readCount(namedScores, "meal_as_chat"),
    chatAsMeal: readCount(namedScores, "chat_as_meal"),
  };
};

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
    results: z.array(
      z.object({ vars: z.object({ text: z.string() }), error: z.string().nullish() }),
    ),
  }),
});

const readCount = (namedScores: Record<string, number>, name: ClassificationErrorKind): number => {
  const count = namedScores[name];
  if (count === undefined) {
    throw new Error(`結果に ${name} の数が無い`);
  }
  return count;
};
