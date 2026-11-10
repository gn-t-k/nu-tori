#!/usr/bin/env bash
# この回が作ったシミュレーターだけを止めて消す。証拠（evidence/）とログは残す。
# 使い方: stop.sh <回のフォルダ>
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"

if xcrun simctl list devices -j | jq -e --arg id "$UDID" '[.devices[][] | select(.udid == $id)] | length == 1' > /dev/null; then
    xcrun simctl shutdown "$UDID" 2> /dev/null || true
    xcrun simctl delete "$UDID"
fi
echo "消した。証拠は $run_dir/evidence に残した"
