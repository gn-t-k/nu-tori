import { readClassificationCases } from "./classify/read-classification-cases";
import { summarizeClassificationResults } from "./classify/summarize-classification-results";
import type { CasePassCount } from "./case-pass-count";
import { readReplyResults } from "./reply/read-reply-results";
import { summarizeReplyResults } from "./reply/summarize-reply-results";

// promptfoo で回す評価の組。回すのは run-eval.ts、2つの版で比べるのは compare-eval.ts。
// configPath は server/ からの道。summarize は PR の本文に貼る要約、readCases は版を比べるときの場面ごとの通った回
export const evalSuites = {
  classify: {
    configPath: "evals/classify/promptfooconfig.ts",
    summarize: summarizeClassificationResults,
    readCases: readClassificationCases,
  },
  reply: {
    configPath: "evals/reply/promptfooconfig.ts",
    summarize: summarizeReplyResults,
    readCases: (results) =>
      readReplyResults(results).cases.map(({ id, passedRuns, runs }) => ({
        id,
        passedRuns,
        runCount: runs.length,
      })),
  },
} as const satisfies Record<string, EvalSuite>;

export type EvalSuiteName = keyof typeof evalSuites;

type EvalSuite = {
  configPath: string;
  summarize: (results: unknown) => { summary: string; passed: boolean };
  readCases: (results: unknown) => CasePassCount[];
};
