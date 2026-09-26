#!/bin/bash
# クラウドセッション開始時に、Swift を入れ、mattpocock/skills を skills-lock.json に沿って最新版へ更新する。
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

# 更新に失敗してもセッションは止めない
if ! timeout 120 npx -y skills@latest update -p -y >/dev/null 2>&1; then
  echo "スキルの更新確認に失敗しました（ネットワークなど）。今回は既存のスキルのまま進めます。" >&2
else
  changed=$(git status --porcelain -- .agents/skills .claude/skills skills-lock.json)
  if [ -n "$changed" ]; then
    contexts+=("セッション開始時に mattpocock/skills の更新を取り込み、次のファイルが変わりました。作業中の変更とは別のコミット（例：「mattpocock/skills を更新」）にまとめ、ユーザーにも伝えてください。
$changed")
  fi
fi

if [ ${#contexts[@]} -gt 0 ]; then
  jq -n --arg ctx "$(printf '%s\n\n' "${contexts[@]}")" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
fi
