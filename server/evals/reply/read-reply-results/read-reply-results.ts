import { z } from "zod";

// promptfoo の結果（-o の JSON）から、場面ごとの合否・返事の本文・落ちた守ることと判定の理由を読む。
// 返事を作れなかった場面は、落ちた場面として提供元のエラーを理由にする（回し直すかは読む人が決める）
export const readReplyResults = (
  results: unknown,
): {
  passed: number;
  total: number;
  cases: {
    id: string;
    pass: boolean;
    output: string | undefined;
    failures: { rubric: string; reason: string }[];
  }[];
} => {
  const cases = resultsSchema.parse(results).results.results.map((result) => {
    const failures = (result.gradingResult?.componentResults ?? [])
      .filter(({ pass }) => !pass)
      .map(({ assertion, reason }) => ({
        rubric: assertion.type === "llm-rubric" ? String(assertion.value) : "長さと指し示す食事",
        reason,
      }));
    return {
      id: result.testCase.description,
      pass: result.success,
      output: result.response?.output,
      failures:
        result.success || failures.length > 0
          ? failures
          : [{ rubric: "返事を作る", reason: result.error ?? "理由が無い" }],
    };
  });
  return { passed: cases.filter(({ pass }) => pass).length, total: cases.length, cases };
};

const resultsSchema = z.object({
  results: z.object({
    results: z.array(
      z.object({
        success: z.boolean(),
        testCase: z.object({ description: z.string() }),
        response: z.object({ output: z.string().optional() }).nullish(),
        error: z.string().nullish(),
        gradingResult: z
          .object({
            componentResults: z
              .array(
                z.object({
                  assertion: z.object({ type: z.string(), value: z.unknown() }),
                  pass: z.boolean(),
                  reason: z.string(),
                }),
              )
              .optional(),
          })
          .nullish(),
      }),
    ),
  }),
});
