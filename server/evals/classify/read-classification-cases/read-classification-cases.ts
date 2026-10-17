import { z } from "zod";
import type { CasePassCount } from "../../case-pass-count";

// promptfoo の結果（-o の JSON）から、文章ごとに、回した数と間違えずに読めた回の数を読む（2つの版を比べるときに使う。#565）。
// 間違いの種類ごとの assertion（promptfooconfig.ts）の score が、どれも 0 なら読めた回にする。呼び出しに失敗した回は読めなかった回にする
export const readClassificationCases = (results: unknown): CasePassCount[] => {
  // promptfoo は回し終えた順に並べるので、評価の組の順（--repeat の回は続けて並ぶ）に並べ直す
  const rows = resultsSchema
    .parse(results)
    .results.results.toSorted((a, b) => a.testIdx - b.testIdx);
  const runs = rows.map((result) => ({
    id: result.vars.text,
    pass:
      result.error == null &&
      (result.gradingResult?.componentResults ?? []).every(({ score }) => score === 0),
  }));
  const ids = [...new Set(runs.map(({ id }) => id))];
  return ids.map((id) => {
    const caseRuns = runs.filter((run) => run.id === id);
    return {
      id,
      passedRuns: caseRuns.filter(({ pass }) => pass).length,
      runCount: caseRuns.length,
    };
  });
};

const resultsSchema = z.object({
  results: z.object({
    results: z.array(
      z.object({
        testIdx: z.number(),
        vars: z.object({ text: z.string() }),
        error: z.string().nullish(),
        gradingResult: z
          .object({ componentResults: z.array(z.object({ score: z.number() })).optional() })
          .nullish(),
      }),
    ),
  }),
});
