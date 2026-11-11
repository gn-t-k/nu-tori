#!/usr/bin/env bash
# 回のシミュレーターとアプリが、確かめに使ってよい状態かを読むだけで答える。
# 使い方: doctor.sh <回のフォルダ>
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
[ -n "${BUILT-}" ] || { echo "NG  start.sh が組み終えていない。stop.sh で消し、start.sh で作り直す"; exit 1; }

ok=true
# 1つ目の引数が見出し、残りが確かめるコマンド
check() {
    local label="$1"
    shift
    if "$@"; then echo "ok  $label"; else echo "NG  $label"; ok=false; fi
}
booted() { xcrun simctl list devices -j | jq -e --arg id "$UDID" '[.devices[][] | select(.udid == $id and .state == "Booted")] | length == 1' > /dev/null; }
installed() { xcrun simctl get_app_container "$UDID" "$bundle_id" > /dev/null 2>&1; }

check "この回のシミュレーター（${UDID}）が起動している" booted
check "アプリが入っている" installed
check "アプリが動いている（launch.sh で開いた）" app_running
check "組んだときの ios/（コミット ${COMMIT}）が今の ios/ と同じ" [ "$IOS_TREE" = "$(ios_content_hash)" ]

$ok || { echo "ios/ が違えば stop.sh で消して start.sh から、アプリが動いていなければ launch.sh で開き直す"; exit 1; }
