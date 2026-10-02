import { readFileSync } from "node:fs";
import { join } from "node:path";

// 入っている @praha/byethrow-docs の init が SKILL.md に書き出す instruction を出す。
// scripts/check が、.agents/skills/byethrow/upstream-instruction.md の写しと比べる。
// instruction は export されていないので、ソースのテンプレートリテラルから取り出す
const source = readFileSync(
  join(import.meta.dirname, "../node_modules/@praha/byethrow-docs/dist/esm/cli/commands/init.js"),
  "utf8",
);
const literal = /const instruction = `((?:\\.|[^`\\])*)`\.trim\(\);/su.exec(source)?.[1];
if (literal === undefined || literal.includes("${")) {
  throw new Error(
    "init.js の instruction の書き方が変わった。scripts/print-byethrow-docs-instruction.ts の取り出し方を直す",
  );
}
console.log(
  literal
    .replaceAll(/\\(.)/gsu, (_, escaped: string) => {
      if (escaped !== "`" && escaped !== "\\" && escaped !== "$") {
        throw new Error(`init.js の instruction に読めないエスケープ \\${escaped} がある`);
      }
      return escaped;
    })
    .trim(),
);
