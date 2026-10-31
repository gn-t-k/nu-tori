#!/bin/bash
# Bash のコマンドに pkill -f・pgrep -f（-af のような束ね方と --full を含む）があれば止め、代わりの方法を返す。
# -f はコマンドライン全体に当てるので、そのパターンを含む自分のシェルまで止め（exit 144）、文書の注意書きでは防げなかったため（#787）
set -euo pipefail

command=$(jq -r '.tool_input.command // empty')
# 行の続き（\ と改行）で分けて書いた呼び出しも1行にして照らす
command=${command//$'\\\n'/ }

# ; & | の手前までを1つの呼び出しと見る。引用符の中の文字列（コミットメッセージなど）に書いた分も止まる
if ! grep -qE '(^|[^[:alnum:]_-])(pkill|pgrep)[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*f[[:alpha:]]*|--full)([[:space:]]|$)' <<< "$command"; then
  exit 0
fi

reason="pkill -f・pgrep -f はコマンドライン全体に当たるので、そのパターンを含むこの Bash のシェル自身も止めます（exit 144）。代わりに、run_in_background で回したコマンドは終わりの知らせを待つか、止めるなら ps などで PID を確かめて kill <PID> で止めてください。文字列（コミットメッセージなど）に書いただけなら、Write で書いたファイルで渡してください（heredoc もこのコマンドの文字列に入ります）。"

jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
