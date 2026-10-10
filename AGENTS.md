# nu-tori

## エージェントスキル

### Issue管理

Issueはこのリポジトリ（gn-t-k/nu-tori）のGitHub Issuesで管理する。詳細は `docs/agents/issue-tracker.md` を参照。

### triageラベル

標準の5ラベル（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）を使う。詳細は `docs/agents/triage-labels.md` を参照。

### ドメインドキュメント

単一コンテキスト構成：リポジトリ直下に `GLOSSARY.md` と `docs/adr/` を1つずつ置く。詳細は `docs/agents/domain.md` を参照。

### デザイン

UI を実装・変更するときは、リポジトリ直下の `DESIGN.md`（見た目のトークンとガードレール）があれば従う。従えないところは `DESIGN.md` に例外を書かず、そのコードになぜかをコメントで書く（`docs/agents/coding-style.md` の「コードを説明する情報」）。`docs/ui-design/` は凍結済みの設計記録で、読むときは `docs/agents/decisions.md` を読む。

### コーディングの好み

好みの入口は `CODING_STANDARDS.md` で、レビュー役が読む。PR を出す前と PR に push する前に、`docs/agents/git.md` の好みのレビューを通す。好みのほうが違うと思ったら、ユーザーに聞いてから `CODING_STANDARDS.md` とそこから指す文書を直す。

### 進め方

- ユーザーへの返事と、リポジトリに置く文書は日本語で書く
- 比べるものや流れは、表より図で見せる
- 選択肢を尋ねるときは、今の形と、具体の場面（どの操作で何が起きるか）と、変えたあとの形（フォルダの木・型・表）を見せる。`GLOSSARY.md` に無い語は、使う前に一言で定義する
- UI や振る舞いの選択肢を尋ねるときは、`/prototype` で見比べられるものを先に作る
- 工程のゲートや引き継ぎなどの大きな確認をするときは、`docs/agents/gate-review.md` を読む

### 情報の置き場

決定・用語・見た目・働き方を文書に書く・直す・消すとき、実装した PR を出すとき、今の決定をどこから読むか決めるとき、決定チケットを解決するとき、記録や Issue・PR が指す `AGENTS.md` の節やその中の記述が見つからないときは、`docs/agents/decisions.md` を読む。`AGENTS.md` と、そこから指す `docs/agents/` の文書に書いた働き方は、それを決めた解決コメントや ADR より正とする。働き方を変える決定は、解決コメントに書くのとあわせてこれらを直す。

### リポジトリ全体の決定

- アプリは `ios/`、サーバーは `server/` に置く（モノレポ）。`ios/`・`server/` のファイルを読み書きする前に、そのディレクトリの `AGENTS.md` を読む
- 確かめる手順の入口は `scripts/check` の1本にする。引数なしで両方、`ios`・`server` で片方を確かめ、`--fix` で直してから確かめる。エージェントも人も CI も同じものを呼ぶ。エージェントは、変えたらコミットの前に `scripts/check --fix` を回し、0 で終わるまで直す
- スキルを足す・直すとき、`/wizard` でウィザードを書くとき、hook・MCP・CI の設定を足す・直すとき、Sentry・App Store Connect・Cloudflare・PostHog を読むとき、本番の知らせを Issue にする仕組み（`production-alerts`）に触るときは、`docs/agents/tooling.md` を読む
- 依存と道具（Swift・Node・pnpm など）の版を上げるとき、依存の PR とその落ちた Issue を扱うとき、依存の更新で壊れた本番を戻すときは、`docs/agents/dependencies.md` を読む
- 環境は本番と開発用の2つ。TestFlight と App Store の版は本番に、デバッグビルドは開発用につなぐ。DB、写真の置き場、LLM の API キー、Sign in with Apple の鍵は環境ごとに分け、開発用の LLM のキーには低い費用の上限をかける。Workers AI は、呼ぶときに環境ごとの AI Gateway を通し、開発用のゲートウェイに低い支出の上限をかける
- 計算・判定・検証の決めごと（ドメイン知識）の正本は、既定でサーバーのドメイン層に置く。見た目の決めごと（`DESIGN.md`）と、ヘルスケアとの対応づけのような端末の入出力の変換は、ドメイン知識に含めない。端末に置くのは、サーバーに置くと次のどれかでユーザーが不利益を被るものだけにする（今の一覧は `ios/AGENTS.md`）
  1. 電波がないと、自分の操作の結果が見えない
  2. 操作についてくる速さが要る
  3. アプリが開かれていないとき、または電波がないときにも動く必要がある
- 観測の道具（分け方は ADR-0017）のどれにも、記録の中身（写真、文章、料理と材料の名前、発言の本文、体重・体脂肪率・kcal・栄養の値）を送らず、PostHog に送る数値は数・率・差・所要時間・旗だけにする。観測は申告を待たずに気づくためのもので、人の声は TestFlight のフィードバックと問い合わせで受ける
- 集めるもの、送り先、使い道、残る期間を変えるとき、公開のページ（`site/`）を書く・直すときは、`docs/agents/privacy.md` を読む
- 端末とサーバーの両方に置く決めごと（栄養の合計の数え方、日と週の区切り、受け付ける値の範囲）を書く・直すときは、`docs/agents/shared-rules.md` を読む
- 同期（端末の送り待ちとキャッシュ、サーバーの帳簿、`/v1/sync/*` の API）に触るとき、記録の種類を足すときは、`docs/agents/sync.md` を読む
- DB の表（Durable Object と D1）の形を提案する・足す・変えるとき（表が増える・変わる仕様の `/to-spec` の前と、設計の見直しで表の案を出すときを含む）は、`docs/agents/table-design.md` を読む

### 公開リポジトリ

このリポジトリは公開して開発する（ADR-0010）。開発者自身の健康データ（ヘルスケアの書き出しなど）は、`.gitignore` したファイル（`prototype/0001-expenditure` の `data.local.js` など）にだけ置き、コミットにも Issue・PR・コメントにも書かない。開発者が良いと言ったものは除く。

### git

コミット、PR の作成、ブランチの更新、GitHub の Issue と PR の操作をするときは `docs/agents/git.md` を読む。
