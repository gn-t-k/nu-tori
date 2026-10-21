#!/bin/bash
# 作業ツリーが origin/main より遅れていたら知らせる。クラウドでは続けたセッション（resume・compact・clear）で、
# 手元（Mac）では始めたときも続けたときも見る。
# 長いセッションのあいだに main が進むと、古い版の働き方の文書を読んでしまうため。
# 手元の worktree は古い main から作られることがあり、まだ main に無い道具（scripts/clean-builds など）を探して止まったため、取り込ませる
set -euo pipefail

source=$(jq -r '.source // empty' 2>/dev/null || true)
remote=false
if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
  remote=true
fi

# クラウドで始めたときは、main から取ったばかりなので見ない
if $remote && [ "$source" = startup ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# macOS には timeout コマンドが無い
fetch_main() {
  if command -v timeout > /dev/null; then
    timeout 30 git fetch -q origin main
  else
    git fetch -q origin main
  fi
}

# 取りに行けなくてもセッションは止めない
if ! fetch_main 2>/dev/null; then
  exit 0
fi

behind=$(git rev-list --count HEAD..origin/main)
if [ "$behind" -eq 0 ]; then
  exit 0
fi

if git merge-base --is-ancestor HEAD origin/main; then
  ctx="作業ツリーが origin/main より ${behind} コミット遅れています。働き方の文書（AGENTS.md、docs/agents/ など）を読む前に、origin/main に合わせてください（作業ブランチなら fast-forward、ブランチに付いていなければ git checkout --detach origin/main）。"
elif $remote; then
  ctx="作業ブランチが origin/main より ${behind} コミット遅れています。働き方の文書（AGENTS.md、docs/agents/ など）は、git show origin/main:<パス> で main の版を読んでください。main を取り込むかは、作業に合わせて決めてください。"
else
  ctx="作業ブランチが origin/main より ${behind} コミット遅れています。作業を始める前に git merge origin/main で取り込んでください。衝突したら、解いてから始めてください。"
fi

jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
