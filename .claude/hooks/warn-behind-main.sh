#!/bin/bash
# 続けたセッション（resume・compact・clear）で、作業ツリーが origin/main より遅れていたら知らせる。
# 長いセッションのあいだに main が進むと、古い版の働き方の文書を読んでしまうため。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# 取りに行けなくてもセッションは止めない
if ! timeout 30 git fetch -q origin main 2>/dev/null; then
  exit 0
fi

behind=$(git rev-list --count HEAD..origin/main)
if [ "$behind" -eq 0 ]; then
  exit 0
fi

if git merge-base --is-ancestor HEAD origin/main; then
  ctx="作業ツリーが origin/main より ${behind} コミット遅れています。働き方の文書（AGENTS.md、docs/agents/ など）を読む前に、origin/main に合わせてください（作業ブランチなら fast-forward、ブランチに付いていなければ git checkout --detach origin/main）。"
else
  ctx="作業ブランチが origin/main より ${behind} コミット遅れています。働き方の文書（AGENTS.md、docs/agents/ など）は、git show origin/main:<パス> で main の版を読んでください。main を取り込むかは、作業に合わせて決めてください。"
fi

jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
