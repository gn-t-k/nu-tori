# コーディング規約

コード・テスト・エージェントが読む文書を照らすレビュー役（`docs/agents/review.md` の好みのレビューと、開発者が自分で `/code-review` を呼んだときの Standards の軸）が読む入口。実装役は、書く前に読まなくてよい。

**Why:** 実装役は、調べる・書く・失敗を直すで文脈が埋まっている。差分だけを受け取るレビュー役のほうが、規約を当てる余裕がある（mattpocock/skills の `/retro` の考え）。

## 文書

照らす範囲で変わったファイルの種類で、読む文書を選ぶ。読むのは、条件に当たる文書だけにする。

- コードか依存のファイル（`.ts`・`.swift`・シェルのスクリプト・CI のワークフロー・`package.json`・lockfile・`Package.swift` など、テストを含む）が変わったとき
  - `docs/agents/coding-style.md`: 言語に寄らない好み
  - `.agents/skills/code-review/SKILL.md` の「3. Identify the standards sources」: 臭いの一覧（smell baseline）と、それを当てる決まり。その節だけを読む
  - `docs/agents/languages/<言語>.md`: 言語ごとの当てはめ。変わったファイルの言語のものだけを読む
- テストのファイル（`*.test.ts`、`testing/` の下、Swift の `*Tests/` の下など）が変わったとき: `docs/agents/testing.md`（テストの好み）
- エージェントが読む文書（`AGENTS.md`、`CODING_STANDARDS.md`、`docs/agents/`、`.agents/skills/`、`.claude/skills/`、`.claude/agents/`）が変わったとき: `.agents/skills/writing-for-agents/SKILL.md`（その書き方）
- 画面のファイル（`ios/NuTori/` の下で `import SwiftUI` のある `.swift`（一覧の `.swift` を `grep -l '^import SwiftUI'` で見分ける）、`ios/NuTori/Assets.xcassets/` の下、`site/public/` の下、`site/src/` の下の `.tsx`。どれもテストを除く）が変わったとき: `DESIGN.md`（見た目のトークンとガードレール）
- LP と掲載情報の文言のファイル（`site/src/pages/` の下、`site/src/` の下で名前に `landing` を含むもの、掲載情報の正本の `site/src/app-store-connect-listing.ts`・`site/src/app-store-screenshots.ts`、両方に載る医療の一文の `site/src/medical-disclaimer.ts`。どれもテストを除く）が変わったとき: `docs/agents/marketing.md`（文言の決まり）
- コードのファイル（上の1つ目の条件の `.ts`・`.swift`。テストを除く）を新しく足したとき（範囲の差分の `--name-status` で `A`）: `.agents/skills/codebase-design/SKILL.md`（深さ、継ぎ目の置き場、消してみる試し、アダプタの数）

どの条件にも当たらないファイルだけのときは、上の文書を読まずに、下の「指摘するもの」の一般論を当てる。

**Why:** 画面・LP と掲載情報の文言・新しいモジュールの3つは、照らす役がいなかった。`DESIGN.md` との食い違いは、#874 では開発者が LP の絵を見て、#221 では別の作業のエージェントが見つけていた（#980 の漏れ1・2・10）。

**Why:** 条件は一部の文書の行末にしか無く、レビュー役の定義も差分を見る前に「ここから指す文書を読む」と言っていたので、レビュー役が周ごとに全部を読み直し、1行の差分や Markdown だけの差分にも1周で約4.7万〜11万トークンかかっていた（#929）。

## 指摘するもの

- 文書のルールから外れている箇所。当たったルールの文書と見出しを添える
- 文書に無くても、一般に良くないとされる書き方（不具合のもとになる、読み手を誤らせる、保守を重くする）。何が良くないかを添える。上の「文書」にある臭いの一覧もここに入る

文書のルールと一般論が食い違うときは、文書に従う。人によって意見が分かれる書き方（好み）は、文書にあるものだけを指摘し、ルールの読み方で判断が分かれるものは見送る。

指摘には、ファイル、行、直し方を添え、文書のルールか一般論かを分けて書く。

## ルールを足すとき

- 文書には、人によって意見が分かれる好みだけを書く。一般に良くないとされるものは、書かなくてもレビュー役が指摘する
- 機械で見分けられるもの（使わない API、import の形、ファイルの置き場）は、文書でなく `scripts/check` の検査にする
