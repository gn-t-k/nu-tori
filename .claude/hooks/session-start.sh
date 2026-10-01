#!/bin/bash
# クラウドセッション開始時に、Swift を入れ、mattpocock/skills の更新を確かめる（更新があれば別の PR にするよう伝える）。
# settings.json で async 実行しているので、結果は次のターンでClaudeに届く。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

contexts=()

# 失敗してもセッションは止めない
if ! swift_log=$(scripts/install-swift 2>&1); then
  contexts+=("セッション開始時に Swift を入れられませんでした。scripts/check ios の前に scripts/install-swift を動かし、直らなければユーザーに伝えてください。
$swift_log")
fi

# 作業ツリーに触れず、更新を作業の PR に混ぜないため、別の worktree で確かめる。
# 更新に失敗してもセッションは止めない
skills_tree=$(mktemp -d)
if ! { timeout 30 git fetch -q origin main && git worktree add -q --detach "$skills_tree" origin/main; } >/dev/null 2>&1; then
  echo "スキルの更新を確かめる worktree を作れませんでした。今回は既存のスキルのまま進めます。" >&2
elif ! (cd "$skills_tree" && timeout 120 npx -y skills@latest update -p -y >/dev/null 2>&1); then
  git worktree remove --force "$skills_tree" >/dev/null 2>&1 || true
  echo "スキルの更新確認に失敗しました（ネットワークなど）。今回は既存のスキルのまま進めます。" >&2
else
  changed=$(git -C "$skills_tree" status --porcelain)
  if [ -z "$changed" ]; then
    git worktree remove --force "$skills_tree" >/dev/null 2>&1 || true
  else
    contexts+=("mattpocock/skills に更新がありました。更新は ${skills_tree}（origin/main から作った worktree）に当ててあり、作業ツリーは変わっていません。作業中のブランチとは別の PR にしてください。
1. 開いている PR に、ブランチ名が claude/update-mattpocock-skills で始まるものがあれば、PR を作らずに git worktree remove --force ${skills_tree} で消す
2. 無ければ、その worktree でブランチ claude/update-mattpocock-skills-<今日の日付> を作り、「mattpocock/skills を更新」のコミットにして push し、PR を出してユーザーに伝える。終わったら worktree を消す
変わったファイル:
$changed")
  fi
fi

if [ ${#contexts[@]} -gt 0 ]; then
  jq -n --arg ctx "$(printf '%s\n\n' "${contexts[@]}")" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
fi
