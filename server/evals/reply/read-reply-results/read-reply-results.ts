import { z } from "zod";

// promptfoo の結果（-o の JSON）から、場面ごとの回の合否・返事の本文・落ちた守ることと判定の理由を読む。
// --repeat で何回か回した結果は、場面ごとに回の並びにまとめる。すべての回で通った場面を、通った場面に数える。
// 返事を作れなかった回は、落ちた回として提供元のエラーの1行目（スタックを除く）を理由にする（回し直すかは読む人が決める）
export const readReplyResults = (
  results: unknown,
): {
  passed: number;
  total: number;
  cases: {
    id: string;
    passedRuns: number;
    runs: {
      pass: boolean;
      output: string | undefined;
      failures: { rubric: string; reason: string }[];
    }[];
  }[];
} => {
  // promptfoo は回し終えた順に並べるので、評価の組の順（--repeat の回は続けて並ぶ）に並べ直す
  const rows = resultsSchema
    .parse(results)
    .results.results.toSorted((a, b) => a.testIdx - b.testIdx);
  const runs = rows.map((result) => {
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
          : [{ rubric: "返事を作る", reason: result.error?.split("\n")[0] ?? "理由が無い" }],
    };
  });
  const ids = [...new Set(runs.map(({ id }) => id))];
  const cases = ids.map((id) => {
    const caseRuns = runs
      .filter((run) => run.id === id)
      .map(({ pass, output, failures }) => ({ pass, output, failures }));
    return { id, passedRuns: caseRuns.filter(({ pass }) => pass).length, runs: caseRuns };
  });
  return {
    passed: cases.filter((evalCase) => evalCase.passedRuns === evalCase.runs.length).length,
    total: cases.length,
    cases,
  };
};

const resultsSchema = z.object({
  results: z.object({
    results: z.array(
      z.object({
        success: z.boolean(),
        testIdx: z.number(),
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
