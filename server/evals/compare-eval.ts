import { execFileSync } from "node:child_process";
import { cp, mkdir, mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describeCommit } from "./describe-commit";
import { evalSuites } from "./eval-suites";
import { exitIfEvalKeyFails } from "./exit-if-eval-key-fails";
import { formatCaseComparison } from "./format-case-comparison";
import { parseEvalArguments } from "./parse-eval-arguments";
import { runPromptfoo } from "./run-promptfoo";
import { serverDirectory } from "./server-directory";

// 同じ評価を、もとの版（ref。main など）と今の作業ツリーで回し、場面ごとの通った回を並べて出す（#565）。
// 回し方（手で）: server/ で `pnpm run evals:compare reply main --repeat 3`。鍵は run-eval.ts と同じ。結果の JSON は .scratch/compare/ に書く。
// もとの版は一時のフォルダの worktree に取り出し、評価（evals/）を今の作業ツリーのもので置き換える。
// もとの版に評価のスクリプトが無くても、同じ場面と合否の決まりで比べられるように。
// worktree を作業ツリーの中に置かないのは、写した evals/ のテストを Vitest が拾わないようにするため。
// 依存（node_modules）も今の作業ツリーのものをつなぐ。評価が import する src/ の関数の形がもとの版と違うと動かない
// トップレベルで呼ぶので、使うより前に置く
const usage = "tsx evals/compare-eval.ts <classify|reply> <ref> [--repeat N]";

const git = (args: readonly string[]): string =>
  execFileSync("git", args, { cwd: serverDirectory, encoding: "utf8" }).trim();

const { suiteName, rest, repeat } = parseEvalArguments(process.argv.slice(2), usage);
const [ref, ...unknownArguments] = rest;
if (ref === undefined || unknownArguments.length > 0) {
  throw new Error(`使い方: ${usage}`);
}
const suite = evalSuites[suiteName];

await exitIfEvalKeyFails();
const baseSha = git(["rev-parse", "--verify", `${ref}^{commit}`]);
const resultsDirectory = path.join(serverDirectory, ".scratch", "compare");
await mkdir(resultsDirectory, { recursive: true });
// 前に止まって消えた worktree の記録を片づけてから取り出す
git(["worktree", "prune"]);
const worktree = path.join(await mkdtemp(path.join(tmpdir(), "nu-tori-evals-")), "repository");
git(["worktree", "add", "--detach", worktree, baseSha]);
try {
  const baseServer = path.join(worktree, "server");
  await rm(path.join(baseServer, "evals"), { recursive: true, force: true });
  await cp(path.join(serverDirectory, "evals"), path.join(baseServer, "evals"), {
    recursive: true,
  });
  await symlink(path.join(serverDirectory, "node_modules"), path.join(baseServer, "node_modules"));

  const baseResults = await runPromptfoo({
    directory: baseServer,
    configPath: suite.configPath,
    repeat,
    outputPath: path.join(resultsDirectory, `${suiteName}-${baseSha}.json`),
  });
  const headResults = await runPromptfoo({
    directory: serverDirectory,
    configPath: suite.configPath,
    repeat,
    outputPath: path.join(resultsDirectory, `${suiteName}-head.json`),
  });
  console.log(
    [
      `場面ごとに回した数: ${repeat}`,
      "",
      formatCaseComparison(
        { label: `${ref}（${baseSha}）`, cases: suite.readCases(baseResults) },
        {
          label: `作業ツリー（${describeCommit(serverDirectory)}）`,
          cases: suite.readCases(headResults),
        },
      ),
    ].join("\n"),
  );
} finally {
  git(["worktree", "remove", "--force", worktree]);
  await rm(path.dirname(worktree), { recursive: true, force: true });
}
