#!/usr/bin/env bash
# 端末と同じ形で書き込みを送る（POST /v1/sync/writes）。書き込みの id は省けば足す。
# 使い方: push.sh <回のフォルダ> <セッションの名前> '<書き込みの JSON の配列>'
#   例: push.sh "$run" main "[{\"type\":\"create_weight_record\",\"weightRecord\":{\"id\":\"$(uuid.sh)\",\"weightKg\":60.5,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\"}}]"
#   記録の id（weightRecord.id など）は自分で付ける（uuid.sh）。あとで同じ記録を指すため
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
session="${2:?セッションの名前を渡す}"
writes="${3:?書き込みの JSON の配列を渡す}"

filled="$(jq -c '.[]' <<< "$writes" | while read -r write; do
    jq -c --arg id "$("$script_dir/uuid.sh")" '.id //= $id' <<< "$write"
done | jq -sc .)"
request="$(jq -n --argjson clientState "$(client_state)" --argjson writes "$filled" '{clientState: $clientState, writes: $writes, isFinalBatch: false}')"
"$script_dir/api.sh" "$run_dir" "$session" POST /v1/sync/writes -H 'content-type: application/json' --data "$request"
