import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { serverDirectory } from "./server-directory";

// promptfoo で評価を1回回し、結果（-o の JSON）を読んで返す。
// directory は promptfoo を回す場所（設定と、設定が import するものを読む server/。版を比べるときは、もとの版の worktree の server/）。
// promptfoo そのものは、今の作業ツリーの server/ に入っているものを使う。
// 通らない場面があると promptfoo は 100 で終わるので、それは回し終えたとみなす
export const runPromptfoo = async ({
  directory,
  configPath,
  repeat,
  outputPath,
}: {
  directory: string;
  configPath: string;
  repeat: number;
  outputPath: string;
}): Promise<unknown> => {
  const promptfoo = path.join(serverDirectory, "node_modules", ".bin", "promptfoo");
  const { status } = spawnSync(
    promptfoo,
    [
      "eval",
      "-c",
      configPath,
      "--repeat",
      String(repeat),
      "-o",
      outputPath,
      "--no-cache",
      "--no-write",
      "--no-table",
    ],
    {
      cwd: directory,
      stdio: "inherit",
      env: { ...process.env, PROMPTFOO_DISABLE_TELEMETRY: "1", PROMPTFOO_DISABLE_UPDATE: "1" },
    },
  );
  // 通らない場面があったときの終わり方（既定の PROMPTFOO_FAILED_TEST_EXIT_CODE）
  const failedTestExitCode = 100;
  if (status !== 0 && status !== failedTestExitCode) {
    throw new Error(`promptfoo が終わり方 ${status} で止まった`);
  }
  return JSON.parse(await readFile(outputPath, "utf8"));
};
