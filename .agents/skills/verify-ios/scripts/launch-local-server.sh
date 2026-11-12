#!/usr/bin/env bash
# この回のシミュレーターで、アプリの API だけを verify-server で立てた手元のサーバーにつないで開く。開いていれば閉じてから開き直す。
# サインインは、verify-server の device.sh sign-in で作ったセッションを渡す。引数なしで使い方を出す
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
if [ $# -lt 3 ]; then
    cat >&2 << 'USAGE'
使い方: launch-local-server.sh <回のフォルダ> <verify-server の回のフォルダ> <セッションの名前> [<名前>=<値>]...
  セッションは .agents/skills/verify-server/scripts/device.sh sign-in <verify-server の回のフォルダ> <セッションの名前> で作る
  <名前>=<値> は launch.sh と同じく起動の値を足す・替える
USAGE
    exit 2
fi
ios_run="$1"
server_run="$2"
session="$server_run/sessions/$3.json"
shift 3
[ -f "$server_run/run.env" ] || { echo "$server_run に run.env が無い（verify-server の start.sh が出した回のフォルダを渡す）" >&2; exit 2; }
[ -f "$session" ] || { echo "$session が無い（verify-server の device.sh sign-in で作る）" >&2; exit 2; }
base_url="$(sed -n 's/^BASE_URL=//p' "$server_run/run.env")"
[ -n "$base_url" ] || { echo "$server_run/run.env に BASE_URL が無い" >&2; exit 2; }
# 値が無いまま開くと、偽の同期サーバーにも手元のサーバーにもつながらない。-e で null も失敗にする
session_token="$(jq -er .sessionToken "$session")" ||
    { echo "$session に sessionToken が無い（verify-server の device.sh sign-in で作り直す）" >&2; exit 2; }
account_id="$(jq -er .accountId "$session")" ||
    { echo "$session に accountId が無い（verify-server の device.sh sign-in で作り直す）" >&2; exit 2; }

# 記録は取りに行って始めるので、初回の取得を終えていないサインイン済みにする。
# 時計は今にする。launch.sh の既定の日のままだと、サーバーの今と食い違う
exec "$script_dir/launch.sh" "$ios_run" signed-in-fetching online \
    "UI_TEST_NOW=$(TZ=Asia/Tokyo date +%Y-%m-%dT%H:%M)" \
    "UI_TEST_SERVER_URL=$base_url" \
    "UI_TEST_SESSION_TOKEN=$session_token" \
    "UI_TEST_ACCOUNT_ID=$account_id" \
    "$@"
