#!/usr/bin/env bash
# 回のサーバーが、確かめに使ってよい状態かを読むだけで答える。
# 使い方: doctor.sh <回のフォルダ>
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"

ok=true
# 1つ目の引数が見出し、残りが確かめるコマンド
check() {
    local label="$1"
    shift
    if "$@"; then echo "ok  $label"; else echo "NG  $label"; ok=false; fi
}
health_is_ok() { [ "$(curl -s --max-time 5 "$BASE_URL/health")" = '{"status":"ok"}' ]; }

check "この回が立てた wrangler dev（PGID ${PGID}）が動いている" kill -0 "$PGID"
check "ログに $BASE_URL で立ったとある" grep -q "Ready on $BASE_URL" "$run_dir/wrangler.log"
check "GET /health が ok を返す" health_is_ok
check "立てたときの server/（コミット ${COMMIT}）が今の server/ と同じ" [ "$SERVER_TREE" = "$(server_content_hash)" ]

$ok || { echo "NG があれば stop.sh で止め、start.sh で立て直す"; exit 1; }
