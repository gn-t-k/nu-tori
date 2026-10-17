import { parseArgs } from "node:util";
import { type EvalSuiteName, evalSuites } from "./eval-suites";

// run-eval.ts と compare-eval.ts の引数を読む。1つ目は評価の組の名前、--repeat N で場面ごとに回す数（既定 1）。
// 読めなければ使い方を添えて投げる
export const parseEvalArguments = (
  args: readonly string[],
  usage: string,
): { suiteName: EvalSuiteName; rest: string[]; repeat: number } => {
  const { positionals, values } = parseArgs({
    args: [...args],
    allowPositionals: true,
    options: { repeat: { type: "string", default: "1" } },
  });
  const [suiteName, ...rest] = positionals;
  const repeat = Number(values.repeat);
  if (!isEvalSuiteName(suiteName) || !Number.isInteger(repeat) || repeat < 1) {
    throw new Error(`使い方: ${usage}`);
  }
  return { suiteName, rest, repeat };
};

const isEvalSuiteName = (name: string | undefined): name is EvalSuiteName =>
  name !== undefined && Object.hasOwn(evalSuites, name);
