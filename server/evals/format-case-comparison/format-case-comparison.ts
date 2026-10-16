import type { CasePassCount } from "../case-pass-count";

// 2つの版で回した同じ評価の結果を、場面ごとに並べた表（PR の本文に貼る形）にする（#565）。
// 揺れる場面がどちらに動いたかを、行を見比べずに拾えるように印を付ける
export const formatCaseComparison = (base: ComparedRun, head: ComparedRun): string => {
  const ids = [...new Set([...head.cases, ...base.cases].map(({ id }) => id))];
  const rows = ids.map((id) => {
    const baseCase = base.cases.find((evalCase) => evalCase.id === id);
    const headCase = head.cases.find((evalCase) => evalCase.id === id);
    const change = formatChange(baseCase, headCase);
    return `| ${id} | ${formatCount(baseCase)} | ${formatCount(headCase)} | ${change === "" ? "" : `${change} `}|`;
  });
  return [
    `| 場面 | ${base.label} | ${head.label} | |`,
    "|---|---|---|---|",
    ...rows,
    `| すべての回で通った場面 | ${formatAllPassed(base)} | ${formatAllPassed(head)} | |`,
  ].join("\n");
};

type ComparedRun = { label: string; cases: readonly CasePassCount[] };

const formatCount = (evalCase: CasePassCount | undefined): string =>
  evalCase === undefined ? "—" : `${evalCase.passedRuns}/${evalCase.runCount}`;

const formatChange = (
  baseCase: CasePassCount | undefined,
  headCase: CasePassCount | undefined,
): string => {
  if (baseCase === undefined || headCase === undefined) {
    return "";
  }
  const change = headCase.passedRuns / headCase.runCount - baseCase.passedRuns / baseCase.runCount;
  return change > 0 ? "↑" : change < 0 ? "↓" : "";
};

const formatAllPassed = ({ cases }: ComparedRun): string =>
  `${cases.filter(({ passedRuns, runCount }) => passedRuns === runCount).length}/${cases.length}`;
