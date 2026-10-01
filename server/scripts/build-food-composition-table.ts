// 日本食品標準成分表（八訂）増補2023年の本表（第2章のデータの Excel）から、サーバーに同梱するデータファイルを作る
//
// 使い方（server/ で）:
//   pnpm exec tsx scripts/build-food-composition-table.ts [Excel のパス]
// パスを省くと、文部科学省のサイトから Excel を取ってくる。成分表の版を上げるときは、下の source を直して回す
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { readSheet } from "read-excel-file/node";
import { buildFoodCompositionEntries } from "./food-composition-table/build-food-composition-entries";

const source = {
  title: "日本食品標準成分表（八訂）増補2023年",
  publisher: "文部科学省",
  page: "https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html",
  file: "https://www.mext.go.jp/content/20260327-mxt_kagsei-mext-000029402_02.xlsx",
  fileDescription: "第2章（データ）の Excel の「表全体」シート",
  fileUpdatedOn: "2026-03-27",
  unit: "栄養の値は可食部 100 g あたり",
};
const outputPath = join(
  import.meta.dirname,
  "../src/domain/food-composition/food-composition-table.json",
);
const wholeTableSheet = 1;

const excelPath = process.argv[2];
const input = excelPath ?? Buffer.from(await (await fetch(source.file)).arrayBuffer());
const entries = buildFoodCompositionEntries(await readSheet(input, wholeTableSheet));

// 食品ごとに1行にして、成分表の版を上げたときの差分を追いやすくする
writeFileSync(
  outputPath,
  `{\n"source": ${JSON.stringify(source)},\n"foods": [\n${entries
    .map((entry) => JSON.stringify(entry))
    .join(",\n")}\n]\n}\n`,
);
console.log(`${entries.length} 食品を ${outputPath} に書いた`);
