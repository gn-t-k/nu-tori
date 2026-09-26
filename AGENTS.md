# nu-tori

## エージェントスキル

### Issue管理

Issueはこのリポジトリ（gn-t-k/nu-tori）のGitHub Issuesで管理する。詳細は `docs/agents/issue-tracker.md` を参照。

### triageラベル

標準の5ラベル（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）を使う。詳細は `docs/agents/triage-labels.md` を参照。

### ドメインドキュメント

単一コンテキスト構成：リポジトリ直下に `CONTEXT.md` と `docs/adr/` を1つずつ置く。詳細は `docs/agents/domain.md` を参照。

### デザイン

UI を実装・変更するときは、リポジトリ直下の `DESIGN.md`（見た目のトークンとガードレール）があれば従う。`docs/ui-design/` は凍結済みの設計記録で、現在の用語と決定は下の「情報の置き場」のとおり。

### コーディングの好み

コード・テスト・依存を書く・直す前に、`docs/agents/coding-style.md` と `docs/agents/testing.md`、その言語の `docs/agents/languages/<言語>.md`（あれば）を読む。PR を出す前と PR に push する前に、`docs/agents/git.md` の好みのレビューを通す。好みのほうが違うと思ったら、ユーザーに聞いてからこれらを直す。

### スキルの管理

mattpocock/skills は `skills-lock.json` で管理し、`.claude/hooks/session-start.sh` で自動更新している。更新で上書きされるため、`.agents/skills/` 配下は直接編集しない。Claude Code は `.claude/skills/`（`.agents/skills/` へのリンク）を、Codex は `.agents/skills/` を読む。`.claude/skills/` にだけある `model-based-ui-design` は、Codex からは見えない。

### 進め方

- ユーザーへの返事と、リポジトリに置く文書は日本語で書く
- 比べるものや流れは、表より図で見せる
- UI や振る舞いの選択肢を尋ねるときは、`/prototype` で見比べられるものを先に作る
- 工程のゲートや引き継ぎなどの大きな確認は、新しい文脈のサブエージェントにその工程のスキルの観点と、下の「情報の置き場」の観点でレビューさせる。指摘ごとに、直さないとあとのセッションが何を間違えるかを確かめ、1行で言えるものだけ直し、ほかは見送る理由を書く。ストックの重複と、フローを今の決定の正本にしていることは、必ず直す。直したら、直した箇所が正しく反映されたかを確かめ、また新しい文脈でレビューさせる。直すものが0件になるか、3回回したら止める。3回目でも直すものが残ったら、それを開発者に見せて決めてもらう

### 情報の置き場

情報は、今の状態を保つ**ストック**と、その時点の記録の**フロー**に分けて置く。

- ストックは直して保つ。1つの内容は1か所にだけ書き、ほかからは指す
  - 決定: 関係するディレクトリの `AGENTS.md`（リポジトリ全体はこのファイル、アプリは `ios/AGENTS.md`、サーバーは `server/AGENTS.md`）。端末とサーバーの両方に置くドメイン知識は、正本のあるサーバー側（`server/AGENTS.md` の「端末とサーバーの両方に置く決めごと」）に書き、`ios/AGENTS.md` からは指す
  - 用語は `CONTEXT.md`、見た目は `DESIGN.md`、好みは `docs/agents/`
  - Issue の本文: マップと、各チケットの今の問い
  - コードとテスト: 実装した決定の正本。実装とテストで読める決定を文書にも残すと、コードのキャッシュになって古くなるので、実装した PR で文書からその決定を消し、テストへ移す。文書に残すのは、コードから読めない理由、コードを書く前に要る境界と置き場、コードの外で確かめること、まだ実装していない決定
- フローには、その時点で決めたことと理由を書き、あとから直さない。今の状態はフローから読ませず、ストックへのリンクを書く
  - ADR（決めたこと、検討した案、選ばなかった理由）、Issue のコメント、PR、コミットメッセージ、`docs/research/`（日付つきの調査）、`docs/ui-design/`（凍結済みの設計記録）
- 決定が変わったら、ストックを直し、経緯は新しいフロー（ADR、コミット）に書く
- この分け方（「[サーバーの言語と実行基盤](https://github.com/gn-t-k/nu-tori/issues/25)」で決めた）より前の決定は、まだ `docs/adr/` と、マップ「[初回リリースの実装に向けた技術の決定](https://github.com/gn-t-k/nu-tori/issues/19)」の「これまでの決定事項」が指す、この分け方より前に閉じたチケットの解決コメントにしか無いものがある。ストックに書き起こすまでは、そこも今の決定として読む。ストックと食い違うときは、ストックを正とする（「[今も有効な決定をストックに書き起こす](https://github.com/gn-t-k/nu-tori/issues/50)」）

### リポジトリ全体の決定

- アプリは `ios/`、サーバーは `server/` に置く（モノレポ）。`ios/`・`server/` のファイルを読み書きする前に、そのディレクトリの `AGENTS.md` を読む
- 確かめる手順の入口は `scripts/check` の1本にする。引数なしで両方、`ios`・`server` で片方を確かめ、`--fix` で直してから確かめる。エージェントも人も CI も同じものを呼ぶ。エージェントは、変えたらコミットの前に `scripts/check --fix` を回し、0 で終わるまで直す。CI は変わったパスでジョブを分け、main のルールセットでは `ios-app` 以外のジョブをすべて必須にする。飛ばすのはジョブの条件（変わったファイルを判定するステップ）で行う。ワークフローの `paths` で飛ばすと、必須のチェックが保留のまま残る
- 確かめることは `scripts/check` と CI に置き、Claude Code の hook は便利のためだけに使う（Codex と Cursor では hook が動かない）。クラウドのエージェントの Linux には `scripts/install-swift` で Swift を入れる。版を `ios/.swift-version` の1か所に置くため、環境の Setup script ではなく、Claude Code では SessionStart hook が裏で呼ぶ。新しいセッションの最初の40秒ほどは Swift が無い。無ければ `scripts/install-swift` を動かす（hook が入れている途中なら、入れ終わるのを待ってから戻る）
- MCP のサーバーは、Claude Code（`.mcp.json`）・Codex（`.codex/config.toml`）・Cursor（`.cursor/mcp.json`）の3つの設定に同じものを置き、版や環境変数は起動スクリプト（`scripts/mobilebuildmcp`）の1か所に書く
- 依存の更新は Dependabot にし、Renovate は入れない。外の App にワークフローへの書き込みを渡さずに済むため。代わりに、Renovate なら追える CI のコンテナの digest と SwiftLint を手で上げる（`ios/AGENTS.md` の「版を上げる」）。Dependabot の PR にコミットを足すと、Dependabot はその PR を rebase しなくなるので、手で上げるものは別の PR にし、Dependabot の PR の CI を直したら早くマージする
- GitHub Actions の秘密の値は、main からだけ使える Environment に置く（ADR-0010）
- 環境は本番と開発用の2つ。TestFlight と App Store の版は本番に、デバッグビルドは開発用につなぐ。DB、写真の置き場、LLM の API キー、Sign in with Apple の鍵は環境ごとに分け、開発用の LLM のキーには低い費用の上限をかける
- 計算・判定・検証の決めごと（ドメイン知識）の正本は、既定でサーバーのドメイン層に置く。見た目の決めごと（`DESIGN.md`）と、ヘルスケアとの対応づけのような端末の入出力の変換は、ドメイン知識に含めない。端末に置くのは、サーバーに置くと次のどれかでユーザーが不利益を被るものだけにする（今の一覧は `ios/AGENTS.md`）
  1. 電波がないと、自分の操作の結果が見えない
  2. 操作についてくる速さが要る
  3. アプリが開かれていないとき、または電波がないときにも動く必要がある
- 端末とサーバーの両方に置く決めごと（栄養の合計の数え方、日と週の区切り、受け付ける値の範囲）の中身は、`server/AGENTS.md` の「端末とサーバーの両方に置く決めごと」に書く。これらは、係数や範囲をデータにしてリポジトリの1か所に置き、両側で読む。手順は両側に書き、入力と期待値の JSON を1か所に置いて両方のテストで読む。値や検証の結果が違ったときは、サーバーを正とする。小さな純粋な計算の域を超えたら、TypeScript で1回だけ書き、端末では JavaScriptCore で動かす

### 公開リポジトリ

このリポジトリは公開して開発する（ADR-0010）。開発者自身の健康データ（ヘルスケアの書き出しなど）は、`.gitignore` したファイル（`prototype/0001-expenditure` の `data.local.js` など）にだけ置き、コミットにも Issue・PR・コメントにも書かない。開発者が良いと言ったものは除く。

### git

コミット、PR の作成、ブランチの更新、GitHub の Issue と PR の操作をするときは `docs/agents/git.md` を読む。
