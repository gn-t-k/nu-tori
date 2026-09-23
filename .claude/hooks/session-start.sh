#!/bin/bash
# クラウドセッション開始時に、mattpocock/skills を skills-lock.json に沿って最新版へ更新する。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# 更新に失敗してもセッションは止めない
if ! timeout 120 npx -y skills@latest update -p -y >/dev/null 2>&1; then
  echo "スキルの更新確認に失敗しました（ネットワークなど）。今回は既存のスキルのまま進めます。" >&2
  exit 0
fi

changed=$(git status --porcelain -- .agents/skills .claude/skills skills-lock.json)
if [ -n "$changed" ]; then
  context="セッション開始時に mattpocock/skills の更新を取り込み、次のファイルが変わりました。作業中の変更とは別のコミット（例：「mattpocock/skills を更新」）にまとめ、ユーザーにも伝えてください。
$changed"
  jq -n --arg ctx "$context" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
fi
