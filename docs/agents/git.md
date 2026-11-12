# git の操作

PR を出す前と PR に push する前に通すもの（検査・照合・確かめ）と、その回し方は `docs/agents/review.md` を読む。

- WIP コミットは、PR を出す前に工程ごとのコミットにまとめる。amend したブランチは `git push --force-with-lease origin <今のブランチ>` で上げ直し、コロンで別のブランチを指さない。許可のルールは `claude/x:<別のブランチ>` の形を確かめずに通すため（`docs/agents/tooling.md` の「許可のルール」）
- まとめ直し（`git reset`・`git commit --amend`）と push は、`&&` でつながず、別の Bash の呼び出しで送る

  **Why:** `git reset --soft origin/main && git commit ... && git push --force-with-lease ...` を1つのコマンドで送ると、auto mode に Git Destructive として拒まれた。分けて送ると通った（#905）
- 作業を終えたら、`docs/agents/review.md` で変更にかかるものを通して PR を出す（聞かずに出すことは `AGENTS.md` の「git」）。`/implement` などのスキルがコミットで終わっていても、PR まで進める。PR を出すことと merge することは別で、merge は下の「PR を merge するのは」の行のとおりにする

  **Why:** PR を出してよいか聞いて止まったセッションが、開発者の返事まで約18時間待った。受け入れ条件に PR の本文の証拠があったセッションは PR まで出していて、どちらが正しいかが文書に無かった（#934）。この決まりが「実装を終えたら」と書かれ、`AGENTS.md` からは PR を作るときにだけ指していたあいだは、文書だけの変更のセッションが Claude Code の既定に従って、PR の前に聞いて止まった（#1028）
- 同じファイルを触る PR は、並んで実装してよい。いくつものセッションが衝突の解消で渋滞したら、開発者が交通整理のセッションを1つ立て、そこが順に解いて merge する。開発者に交通整理がいると言われたセッションは、自分では衝突を解かない
- 積み重ねた PR の前の PR を直したら、後ろのブランチに merge で取り込む。後ろのブランチを rebase すると、レビュー済みの差分とコメントの位置がずれるため
- PR を merge するのは、開発者に言われたとき（「CI が通ったら混ぜて」など）と、`docs/agents/review.md` の「判断なしに通す変更」に当たるときだけにする。merge は許可のルールで確かめずに通るので、止めるものはこの決まりだけになる
- PR の本文は `/pr` の形で、日本語で書く。レビューの結果や、ほかの文書が PR の本文に書くよう求めること（実機の確認、App Privacy の回答）は、その後ろに節を足して書く
- テストを回した結果と動かした結果は、`/pr` の Evidence でなく `## 確かめ`（`docs/agents/review.md` の「確かめの回し方」）の1か所に書く。Evidence には下のスクリーンショットだけを置き、スクリーンショットの無い PR では Evidence の節を省く
- 見た目が変わる PR（アプリの画面、`site/` のページ）は、変えた画面のスクリーンショットを PR の本文の Evidence に置く。push で見た目がまた変わったら撮り直す
  - アプリ: 変えた画面で `attachScreenshot(of:named:)` を呼ぶ UI テストを回し、その画像を使う。呼ぶテストが無ければ、その画面を通る UI テストに足す。クラウドのセッションでは、手で始めた `ios-ui-test.yml` の回の成果物 `ios-ui-test-report` から取る（通った回にも上がる）
  - `site/`: ブラウザで開いて撮る（Linux では入っている Chromium と Playwright）
  - 置き方: Mac のセッションは下の `--attach` で添付する。クラウドのセッションは添付できないので、画像を Artifact（claude.ai の非公開のページ）に載せ、そのリンクを書く。CI の成果物は3日で消えるので、成果物のリンクで済ませない

  **Why:** 見た目の変更を、開発者がスクリーンショットで確かめられないまま PR が merge できる状態になっていた（#710）
- Issue・PR に画像や動画を添付するときは、`gh` の `--attach` を使う（使い方は `--help`）。ファイル名は英数字にする（macOS は濁点を分けた形で持ち、本文の `./ファイル` の参照と一致せず書き換わらない）。添付してよいのは、開発者の健康データが写っていないものだけ（ルートの `AGENTS.md` の「公開リポジトリ」）

## クラウドのセッションで GitHub を操作する

Claude Code on the web のセッション（`CLAUDE_CODE_REMOTE=true`）では、GitHub への通信がプロキシを通り、プロキシが認証を差し込む。

- `GH_TOKEN` には仮の値 `proxy-injected` が入っていて、本物のトークンはプロキシが差し替える。PAT を環境変数に置かない
- GraphQL は PR 用の一部を除いて 403 になり、GraphQL を使う `gh issue ...` や `gh pr ...` は通らない。`gh api repos/<owner>/<repo>/...` の REST を使う
  - 読む: `gh api repos/gn-t-k/nu-tori/issues/<n>`、コメントは `.../issues/<n>/comments`
  - サブ Issue: `.../issues/<親>/sub_issues`（追加は `-X POST -F sub_issue_id=<子の DB ID>`）
  - 依存関係: `.../issues/<n>/dependencies/blocked_by`（追加は `-X POST -F issue_id=<ブロック元の DB ID>`）。すでに張られていると 422「already been taken」が返る
  - 担当者・ラベル・状態: `.../issues/<n>/assignees`、`.../issues/<n>/labels`、`-X PATCH .../issues/<n> -f state=closed`
- 画像や動画は添付できない（試した結果は #357）。添付が要るときは、開発者に頼むか、`mcp__ccd_session__spawn_task` で Mac のセッションを始めるカードを出す
- Issue とコメントを書くと、リンクやコードの前後にバッククォートが足されたり、バッククォートが引用符に変わったりして、書式が崩れることがある（コメントの投稿でも Issue の本文の更新でも、`gh api` でも `mcp__github__*` でも起きた）。書いたら必ず `scripts/diff-posted <元の本文のファイル> <API のパス>` で読み直し（API のパスの書き方は引数なしで出る）、崩れていたら手元に置いた元の本文で書き直す。コメントは `mcp__github__update_issue_comment`、Issue の本文は `gh api -X PATCH .../issues/<n> -F body=@<ファイル>` で直し、もう一度読み直す。空白の無い日本語の文に `[名前](URL)` を埋めると、URL を含む長い語として囲まれやすい。直らないときは、参照の形（文中は `[名前][33]`、末尾に `[33]: URL`）にする。ただし行頭の `- [名前][33]: 本文` は参照の定義と取られて崩れるので、その形の行は文中に URL を書く
- Dependabot へのコマンド（PR へのコメントで送る recreate など）は送れない。コメントや本文に書くと、文字のあいだに「·」（U+00B7）が入って崩れ、Dependabot に届かない（`gh api` でも `mcp__github__*` でも起きた。外す設定は文書に無い。#395）。開発者に頼む
- ワークフローのやり直しは `gh api -X POST repos/gn-t-k/nu-tori/actions/runs/<id>/rerun`（落ちたジョブだけなら `.../rerun-failed-jobs`）でできる（#394）
- ほかのツール（Codex、Cursor、Dependabot）が作った PR の CI の失敗は、その PR のブランチで始めたセッションで直す。クラウドのセッションは、作業ブランチにだけ push できるため
- `mcp__github__*` のツールも使える。Issue、サブ Issue、コメント、PR は扱えるが、依存関係のツールは無いので `gh api` で張る
