# Issue管理：GitHub

このリポジトリのIssueと仕様はGitHub Issuesで管理する。

## 運用ルール

操作にはすべて `gh api` の REST を使う（`gh issue ...` は GraphQL を使い、クラウドのセッションでは 403 で通らないため）。クラウドのセッションでの認証、書いたあとの読み直し、サブ Issue と依存関係の API は `docs/agents/git.md` の「クラウドのセッションで GitHub を操作する」。

- **Issueを作る**：本文をファイルに書き、`jq -n --rawfile b <ファイル> '{title:"...", body:$b, labels:["..."]}' | gh api repos/gn-t-k/nu-tori/issues -X POST --input -`
- **本文の長さ**：Issue の本文とコメントは 65,536 文字まで（バイトではなく文字）。仕様のような長い本文は、投稿の前に `python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read()))' <ファイル>` で数え、6 万文字を超えたら、ほかの節と重なる図や付録をコメントに分ける
- **Issueを読む**：`gh api repos/gn-t-k/nu-tori/issues/<番号>`（ラベルは `.labels[].name`）と、コメントは `gh api repos/gn-t-k/nu-tori/issues/<番号>/comments`
- **Issueを一覧する**：`gh api 'repos/gn-t-k/nu-tori/issues?state=open&per_page=100'`。`labels=<名前>` と `state` で絞り込む。PR も混ざるので、`pull_request` のあるものを除く
- **Issueにコメントする**：`gh api repos/gn-t-k/nu-tori/issues/<番号>/comments -X POST -F body=@<ファイル>`
- **ラベルを付ける／外す**：`gh api repos/gn-t-k/nu-tori/issues/<番号>/labels -X POST -f 'labels[]=...'` ／ `gh api repos/gn-t-k/nu-tori/issues/<番号>/labels/<名前> -X DELETE`
- **クローズする**：コメントを付けてから、`gh api repos/gn-t-k/nu-tori/issues/<番号> -X PATCH -f state=closed -f state_reason=completed`

## PRをtriage対象にするか

**PRを要望の受付窓口として扱う：いいえ。**（外部からのPRを機能要望として扱う場合は「はい」にする。`/triage` がこの設定を読む）

「はい」の場合、PRもIssueと同じラベルと状態で扱う。PR もIssueの REST（`issues/<番号>` のコメント・ラベル・状態）で扱え、PR だけのものは `pulls` の REST を使う。

- **PRを読む**：`gh api repos/gn-t-k/nu-tori/pulls/<番号>` と、上の「Issueを読む」のコメント。差分は `gh api repos/gn-t-k/nu-tori/pulls/<番号> -H "Accept: application/vnd.github.diff"`。
- **triage対象の外部PRを一覧する**：`gh api 'repos/gn-t-k/nu-tori/pulls?state=open&per_page=100'` を実行し、`author_association` が `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` のものだけ残す（`OWNER`／`MEMBER`／`COLLABORATOR` は除く）。
- **コメント／ラベル／クローズ**：上の「運用ルール」の Issue の操作と同じ（番号に PR の番号を入れる）。

GitHubではIssueとPRが同じ番号空間を共有するため、`#42` だけではどちらか分からない。`gh api repos/gn-t-k/nu-tori/issues/42` を読み、`pull_request` があれば PR。

## スキルが「Issue管理に登録する」と言ったとき

GitHub Issueを作る。

## スキルが「該当チケットを取得する」と言ったとき

上の「Issueを読む」の2つを実行する。

## wayfinderの操作

`/wayfinder` が使う。**マップ**は1つのIssueで、その**子**Issueがチケットになる。

- **マップ**：`wayfinder:map` ラベルを付けた1つのIssue。本文にメモ／これまでの決定事項／未解明事項を持つ。上の「Issueを作る」で `labels:["wayfinder:map"]`。
- **子チケット**：GitHubのサブIssueとしてマップに紐づけたIssue（`gh api repos/gn-t-k/nu-tori/issues/<マップ>/sub_issues -X POST -F sub_issue_id=<子の DB ID>` で登録）。サブIssueが使えない場合は、マップ本文のタスクリストに子を追加し、子の本文の先頭に `Part of #<マップ>` と書く。ラベルは `wayfinder:<種類>`（`research`／`prototype`／`grilling`／`task`）。着手したら担当者を作業中の開発者にする。
- **ブロック関係**：GitHubの**ネイティブなIssue依存関係**を使う（UIでも見える正式な表現）。`gh api --method POST repos/<owner>/<repo>/issues/<子>/dependencies/blocked_by -F issue_id=<ブロック元のDB ID>` で依存を追加する。`<ブロック元のDB ID>` はブロック元Issueの数値の**データベースID**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id` で取得。`#番号` や `node_id` ではない）。GitHubは `issue_dependencies_summary.blocked_by`（未解決のブロック元の数。これが実際の関門）を返す。依存関係が使えない場合は、子の本文の先頭に `Blocked by: #<n>, #<n>` と書く。ブロック元がすべてクローズされたらブロック解除とみなす。
- **着手可能なチケットの探し方**：マップの未クローズの子を一覧し（`gh api repos/gn-t-k/nu-tori/issues/<マップ>/sub_issues` のうち `state` が `open` のもの、またはタスクリストの子）、未解決のブロック元があるもの（`issue_dependencies_summary.blocked_by > 0`、または `Blocked by` 行に未クローズのIssueがあるもの）と担当者がいるものを除く。残ったうちマップ上で最初のものを選ぶ。
- **着手宣言**：`gh api repos/gn-t-k/nu-tori/issues/<n>/assignees -X POST -f 'assignees[]=<自分の GitHub のユーザー名>'`。セッションで最初に行う書き込みにする。
- **解決**：上の「Issueにコメントする」で回答を書き、続けて「クローズする」。最後にマップの「これまでの決定事項」に要点とリンクを追記する。

## 仕様をチケットに切る前に

仕様が、まだ main に入っていない仕様や PR の上に書かれているとき（本文に「#n が main に入ってから始める」とあるときなど）は、チケットを切る前に、その仕様が前提にしている名前・書く順・口を main のコードと突き合わせる。ずれていたら、仕様の本文を直してから切る。

**Why:** 「[仕様: 食事を撮って推定する](https://github.com/gn-t-k/nu-tori/issues/188)」は、帳簿を作り直す仕様がマージされる前に書いたため、帳簿の書く順を古い形で書き、要る口も足りていなかった。

## 表の移行のチケットの分け方

1つの仕様で増える・変わる表（Durable Object と D1）は、`/erd-design` でまとめて設計したとおり、1つのチケットでまとめて移行する。記録の種類ごとのチケットはそのチケットのあとに並べ、移行を足さない。

**Why:** 移行は大仕事で、並べたチケットでばらばらに足すと、移行の版の番号と並びの末尾を取り合う（#133 と #135 が同じ版 3 を使った）。経緯は「[サーバーの表を Drizzle で扱うかを決める](https://github.com/gn-t-k/nu-tori/issues/150)」の解決コメント。

## iOS のチケットの分け方

iOS のチケットは、作業する場所で分ける。Mac を閉じているあいだも、クラウドのチケットは Linux のエージェントで進めるため。

| 作業する場所 | 中身 | ラベル | ブロック元 |
| --- | --- | --- | --- |
| クラウド | ロジックのパッケージ、API クライアント、画面のコード、テスト | `ready-for-agent` | 前の実装のチケット |
| Mac | シミュレーターで画面と流れを確かめる（`docs/agents/ios-mac.md`） | `ready-for-agent` と `mac` | 確かめる画面を作る実装のチケット |
| 実機 | TestFlight の版で確かめる（`docs/agents/ios-release.md` の「実機の確認」） | `ready-for-human` | 仕様の Issue（閉じる = main に入り、TestFlight に配られる） |

Mac のチケットは、開発者が Mac の上のエージェントに頼む。開発者が外にいて Mac を開けて置く日は、Mac で `claude remote-control --spawn worktree` を動かし、スマホから頼む。

`/implement-spec` で1つの仕様を1つの統合の PR にまとめるときは、次のようにする。

- 統括が拾うのは、作業する場所がクラウドのチケットだけ（`mac` と `ready-for-human` のラベルのチケットは拾わない）
- 実装のチケットは、統合ブランチに取り込んだら、取り込んだ merge のコミットを書いて閉じる。Mac のチケットのブロックを、merge の前に外すため。統合の PR が閉じるのは仕様の Issue だけにする
- Mac のチケットのブロックが外れたら、開発者に知らせる。統合の PR は、Mac のチケットが閉じるまで merge しない（PR の本文に「merge の前に閉じるもの」として並べる）
