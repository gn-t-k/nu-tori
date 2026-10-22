# git の操作

- WIP コミットは、PR を出す前に工程ごとのコミットにまとめる。amend したブランチは `git push --force-with-lease origin <今のブランチ>` で上げ直し、コロンで別のブランチを指さない。許可のルールは `claude/x:<別のブランチ>` の形を確かめずに通すため（`docs/agents/tooling.md` の「許可のルール」）
- 同じファイルを触る PR は、並んで実装してよい。いくつものセッションが衝突の解消で渋滞したら、開発者が交通整理のセッションを1つ立て、そこが順に解いて merge する。開発者に交通整理がいると言われたセッションは、自分では衝突を解かない
- 積み重ねた PR の前の PR を直したら、後ろのブランチに merge で取り込む。後ろのブランチを rebase すると、レビュー済みの差分とコメントの位置がずれるため
- PR を merge するのは、開発者に言われたとき（「CI が通ったら混ぜて」など）だけにする。merge は許可のルールで確かめずに通るので、止めるものはこの決まりだけになる
- PR の本文は `/pr` の形で、日本語で書く。好みのレビューの結果や、ほかの文書が PR の本文に書くよう求めること（実機の確認、App Privacy の回答）は、その後ろに節を足して書く
- Issue・PR に画像や動画を添付するときは、`gh` の `--attach` を使う（使い方は `--help`）。ファイル名は英数字にする（macOS は濁点を分けた形で持ち、本文の `./ファイル` の参照と一致せず書き換わらない）。添付してよいのは、開発者の健康データが写っていないものだけ（ルートの `AGENTS.md` の「公開リポジトリ」）

## 好みのレビュー

コード・テスト・依存・エージェントが読む文書（`AGENTS.md`、`docs/agents/`、`.agents/skills/`、`.claude/skills/`、`.claude/agents/`）を変えたブランチは、PR を出す前と、PR に push する前に、好みのレビューを通す。`git fetch origin <マージ先のブランチ>` を済ませてから、サブエージェント `preferences-review` を立て、マージ先のブランチと、push の前なら PR の本文にある照らしたコミットを渡す。サブエージェントが fetch すると、auto mode が外への書き込みと見て止めることがある。読む文書、照らす範囲、返す形は、定義（`.claude/agents/preferences-review.md`）にある。`/implement` の中で回す `/code-review` は、この周に数えない。

挙がった箇所を直したら、新しい `preferences-review` を立て、1周目の返事の1行目にある照らしたコミットを渡して、直した分をもう一度照らす。照らすのは2周まで。2周目で挙がった箇所のうち、コメント・名前・並び順のようにその場で閉じるものは直して、照らさずに push する。振る舞いや設計にかかるものは直さずに PR の本文に書き、開発者の判断を待つ。

main や前のブランチを取り込んだだけの push（衝突の解消も手直しも無い merge）では照らさず、`scripts/check` だけを通す。

PR の本文に、好みのレビューの結果（0件か、2周目で直した箇所と残した箇所）と、照らしたコミットを書く。push のたびに更新する。

**Why:** 周を重ねるたびに前の周で見なかった行へ新しい指摘が出て、0件まで5周かかるチケットが続いた。取り込みのたびに PR 全体を照らし直してもいて、マージの間隔が延びていた。2周目の指摘を開発者に聞くと、名前やコメントの直しは毎回「直す」と返り、聞く往復だけが増えていた。

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
