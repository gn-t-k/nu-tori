#!/usr/bin/env bash
# この回のシミュレーターの画面を、回のフォルダの evidence/ に番号つきで残す。
# 使い方: shot.sh <回のフォルダ> <名前>（英数字とハイフン。PR に添付するため）
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
label="${2:?名前を渡す（英数字とハイフン）}"
[[ "$label" =~ ^[A-Za-z0-9-]+$ ]] || { echo "名前は英数字とハイフンだけにする: $label" >&2; exit 2; }

count="$(find "$run_dir/evidence" -name '*.png' | wc -l | tr -d ' ')"
file="$run_dir/evidence/$(printf '%02d' $((count + 1)))-$label.png"
xcrun simctl io "$UDID" screenshot "$file" > /dev/null 2>&1
printf '%s\n' "$(date +%T) shot $(basename "$file")" >> "$run_dir/evidence/actions.log"
echo "$file"
