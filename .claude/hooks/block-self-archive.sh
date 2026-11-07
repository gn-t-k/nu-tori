#!/bin/bash
# archive_session に呼んだセッション自身の ID が渡されたら止め、代わりの手順を返す。
# 自分をアーカイブするとコンテナが解放されてターンが切れ、仕事を終えていてもセッションが FAILED に見えるため（#927）
set -euo pipefail

# 環境変数はクラウドのセッションにだけある。無ければ（Mac のセッションなど）何もしない
own=${CLAUDE_CODE_REMOTE_SESSION_ID-}
if [ -z "$own" ]; then
  exit 0
fi

target=$(jq -r '.tool_input.session_id // empty')
if [ -z "$target" ]; then
  exit 0
fi

# 環境変数の ID は cse_、ツールに渡す ID は session_ で始まり、後ろが同じ
own_suffix=${own#cse_}
target_suffix=${target#session_}
if [ "$target" != "$own" ] && [ "$target_suffix" != "$own_suffix" ]; then
  exit 0
fi

reason="渡した ID はこのセッション自身です。自分をアーカイブすると、コンテナが解放されてターンが切れ、仕事を終えていてもセッションが FAILED に見えます。アーカイブを頼まれていても自分では呼ばず、返事を終えて止まってください。開発者か親のセッションが閉じます。"

jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
