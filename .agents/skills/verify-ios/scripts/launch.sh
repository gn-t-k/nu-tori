#!/usr/bin/env bash
# この回のシミュレーターで、アプリを UI テストと同じ起動の値（偽の同期サーバーの場面）で開く。開いていれば閉じてから開き直す。
# 記録はメモリにだけ置くので、開き直すたびに場面の始めに戻る。引数なしで使い方を出す
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
if [ $# -lt 3 ]; then
    cat >&2 << 'USAGE'
使い方: launch.sh <回のフォルダ> <アカウント> <API の場面> [<名前>=<値>]...
  アカウントと API の場面は ios/NuTori/UITesting/UITestLaunch.swift の Account と API の rawValue（signed-in と previous-day など）
  <名前>=<値> は起動の値を足す・替える（UI_TEST_NOW=2026-10-05T09:00、UI_TEST_PICKED_PHOTOS=1、TZ=UTC など）
USAGE
    exit 2
fi
load_run "$1"
account="$2"
api="$3"
shift 3

# 時計は UI テストの既定（UITestNow.morningBeforeNotice。知らせの時刻より前の朝）。時刻帯は日本に決める
values=("UI_TEST_ACCOUNT=$account" "UI_TEST_API=$api" "UI_TEST_NOW=2026-10-05T06:30" "TZ=Asia/Tokyo" "$@")
child_env=()
for value in "${values[@]}"; do
    [[ "$value" == *=* ]] || { echo "起動の値は <名前>=<値> の形で渡す: $value" >&2; exit 2; }
    child_env+=("SIMCTL_CHILD_$value")
done

xcrun simctl terminate "$UDID" "$bundle_id" 2> /dev/null || true
# 端末の言語によらず、日本の利用者と同じ日付と数の書き方にする
env "${child_env[@]}" xcrun simctl launch "$UDID" "$bundle_id" -AppleLanguages '(ja)' -AppleLocale ja_JP > /dev/null
printf '%s\n' "$(date +%T) launch ${values[*]}" >> "$run_dir/evidence/actions.log"

# 新しい端末での初めての起動は、一覧に出るまで数秒かかる。起動の値を読み違えると、出たあとすぐ止まる（UI_TEST_NOW の形など）。
# 1秒おきに3回続けて（約2秒）一覧に見えたら開いたとする
running_for=0
for _ in $(seq 1 30); do
    if app_running; then running_for=$((running_for + 1)); else running_for=0; fi
    [ "$running_for" -ge 3 ] && break
    sleep 1
done
if [ "$running_for" -lt 3 ]; then
    echo "アプリが止まった。起動の値を見直す（ログは xcrun simctl spawn $UDID log show --last 1m --predicate 'process == \"NuTori\"'）" >&2
    exit 1
fi
echo "開いた: ${values[*]}" >&2
