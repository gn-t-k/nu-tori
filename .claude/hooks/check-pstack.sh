#!/bin/bash
# 入っている pstack（cursor/plugins のプラグイン）の版が pstack-lock.json の版と違えば知らせる。
# クラウドでは環境 nu-tori のセットアップスクリプトが新しいコンテナのたびに最新の版を入れるので lock より新しくなり、
# 手元（Mac）では手で上げるまで変わらないので lock より古くなる（#903）。
set -euo pipefail

installed_file="$HOME/.claude/plugins/installed_plugins.json"
# pstack を入れていない端末（環境 nu-tori 以外のクラウドなど）では知らせない
if [ ! -f "$installed_file" ]; then
  exit 0
fi
installed=$(jq -r '.plugins["pstack@cursor-plugins"][0] // empty | "\(.version) \(.gitCommitSha)"' "$installed_file" 2>/dev/null || true)
if [ -z "$installed" ]; then
  exit 0
fi
read -r installed_version installed_sha <<< "$installed"

cd "$CLAUDE_PROJECT_DIR"

# 古い main から作った手元の worktree で、上げ終わった更新をまた知らせないよう、取ってある origin/main の lock を先に見る
if ! lock=$(git show origin/main:pstack-lock.json 2>/dev/null); then
  lock=$(cat pstack-lock.json 2>/dev/null || true)
fi
locked_version=$(jq -r '.version // empty' <<< "$lock" 2>/dev/null || true)
locked_sha=$(jq -r '.gitCommitSha // empty' <<< "$lock" 2>/dev/null || true)
# gitCommitSha は cursor/plugins 全体のコミットで、ほかのプラグインの変更でも変わるので、比べるのは version だけにする
if [ -z "$locked_version" ] || [ "$installed_version" = "$locked_version" ]; then
  exit 0
fi

newer=$(printf '%s\n%s\n' "$installed_version" "$locked_version" | sort -V | tail -n 1)
if [ "$newer" = "$locked_version" ]; then
  ctx="入っている pstack（${installed_version}）が、pstack-lock.json の版（${locked_version}）より古いです。claude plugin marketplace update cursor-plugins と claude plugin update pstack@cursor-plugins で上げてから Claude Code を立ち上げ直すよう、ユーザーに伝えてください。"
else
  ctx="pstack に更新がありました（pstack-lock.json の ${locked_version} → 入っている ${installed_version}）。作業中のブランチとは別の PR にしてください。
1. 開いている PR に、ブランチ名が claude/update-pstack で始まるものがあれば、何もしない
2. 無ければ、git fetch origin main をしてから git worktree add --detach <一時フォルダ> origin/main で作った worktree で、ブランチ claude/update-pstack-<今日の日付> を作り、pstack-lock.json を version ${installed_version}、gitCommitSha ${installed_sha} に書き換える
3. git clone --filter=blob:none --no-checkout https://github.com/cursor/plugins を一時フォルダに取り、git diff ${locked_sha} ${installed_sha} -- harness/pstack/claude-code/ で変わったところを読む。リポジトリの文書が指す pstack のスキル（git grep pstack で探す）が消えた、名前が変わった、指している場面に合わなくなったなら、指している行を同じ PR で直す
4. 「pstack を ${installed_version} に更新」のコミットにして push し、PR を出してユーザーに伝える。PR の本文には、3 で読んだ変わったところと、指している行を直したかを書く。終わったら worktree と一時フォルダを消す"
fi

jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
