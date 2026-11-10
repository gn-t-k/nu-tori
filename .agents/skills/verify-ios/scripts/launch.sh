#!/usr/bin/env bash
# この回のシミュレーターで、アプリを UI テストと同じ起動の値（偽の同期サーバーの場面）で開く。開いていれば閉じてから開き直す。
# 記録はメモリにだけ置くので、開き直すたびに場面の始めに戻る。
# 使い方: launch.sh <回のフォルダ> <アカウント> <API の場面> [<名前>=<値>]...
#   アカウントと API の場面は ios/NuTori/UITesting/UITestLaunch.swift の Account と API の rawValue（signed-in と previous-day など）
#   <名前>=<値> は起動の値を足す・替える（UI_TEST_NOW=2026-10-05T09:00、UI_TEST_PICKED_PHOTOS=1、TZ=UTC など）
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
if [ $# -lt 3 ]; then
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
fi
load_run "$1"
account="$2"
api="$3"
shift 3

# 既定は UI テストの多くと同じ、知らせの時刻より前の朝（UITestNow.morningBeforeNotice）と日本の時刻
values=("UI_TEST_ACCOUNT=$account" "UI_TEST_API=$api" "UI_TEST_NOW=2026-10-05T06:30" "TZ=Asia/Tokyo" "$@")
child_env=()
for value in "${values[@]}"; do
    [[ "$value" == *=* ]] || { echo "起動の値は <名前>=<値> の形で渡す: $value" >&2; exit 2; }
    child_env+=("SIMCTL_CHILD_$value")
done

xcrun simctl terminate "$UDID" "$bundle_id" 2> /dev/null || true
# 英語の端末でも、UI テストと同じ日本の日付と数の書き方にする
env "${child_env[@]}" xcrun simctl launch "$UDID" "$bundle_id" -AppleLanguages '(ja)' -AppleLocale ja_JP > /dev/null
printf '%s\n' "$(date +%T) launch ${values[*]}" >> "$run_dir/evidence/actions.log"

# 起動の値を読み違えると、アプリはすぐ止まる（UI_TEST_NOW の形など）。数秒動き続けたら開いたとする
sleep 3
if ! app_running; then
    echo "アプリが止まった。起動の値を見直す（ログは xcrun simctl spawn $UDID log show --last 1m --predicate 'process == \"NuTori\"'）" >&2
    exit 1
fi
echo "開いた: ${values[*]}" >&2
