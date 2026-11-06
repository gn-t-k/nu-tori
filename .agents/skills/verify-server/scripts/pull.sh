#!/usr/bin/env bash
# 端末と同じ形で変更を取りに行き（GET /v1/sync/changes）、hasMore が false になるまで続けて、変更の配列を出す。
# 使い方: pull.sh <回のフォルダ> <セッションの名前> [afterSequence（既定は 0）]
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
session="${2:?セッションの名前を渡す}"
after="${3:-0}"

all="[]"
while :; do
    query="$(client_state | jq -r --arg after "$after" '. + {afterSequence: $after} | to_entries | map("\(.key)=\(.value | tostring | @uri)") | join("&")')"
    page="$("$script_dir/api.sh" "$run_dir" "$session" GET "/v1/sync/changes?$query")"
    all="$(jq -c --argjson page "$page" '. + $page.changes' <<< "$all")"
    [ "$(jq -r .hasMore <<< "$page")" = true ] || break
    after="$(jq -r .nextAfterSequence <<< "$page")"
done
echo "$all"
