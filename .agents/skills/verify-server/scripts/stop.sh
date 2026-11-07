#!/usr/bin/env bash
# この回が立てた wrangler dev だけを止め、DB と偽の秘密の値を消す。証拠（evidence/）は残す。
# 使い方: stop.sh <回のフォルダ>
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"

if kill -0 "$PGID" 2> /dev/null; then
    kill -TERM -- "-$PGID" 2> /dev/null || true
    for _ in $(seq 1 10); do
        kill -0 "$PGID" 2> /dev/null || break
        sleep 1
    done
    kill -KILL -- "-$PGID" 2> /dev/null || true
fi
rm -rf "$run_dir/state" "$run_dir/dev.vars" "$run_dir/sessions"
echo "止めた。証拠は $run_dir/evidence に残した"
