import { execFileSync } from "node:child_process";

// 評価した版を、結果に添える形にする（#565）。コミットの SHA と、まだコミットしていない変更があるか
export const describeCommit = (directory: string): string => {
  const sha = git(directory, ["rev-parse", "HEAD"]);
  const dirty = git(directory, ["status", "--porcelain"]) !== "";
  return dirty ? `${sha}（コミットしていない変更あり）` : sha;
};

const git = (directory: string, args: readonly string[]): string =>
  execFileSync("git", args, { cwd: directory, encoding: "utf8" }).trim();
