#!/usr/bin/env bash
# 確かめのサインインの口（POST /v1/e2e/sessions）で新しいアカウントを作り、セッションに名前を付けて残す。
# 使い方: sign-in.sh <回のフォルダ> [セッションの名前（既定は main）] [使い始めたことにする時刻（ISO 8601）]
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
name="${2:-main}"
requested_at="${3-}"

headers=(-H "x-e2e-sign-in-secret: $E2E_SIGN_IN_SECRET")
[ -z "$requested_at" ] || headers+=(-H "x-e2e-requested-at: $requested_at")
body="$(mktemp)"
status="$(curl -s -o "$body" -w '%{http_code}' -X POST "${headers[@]}" "$BASE_URL/v1/e2e/sessions")"
log_evidence "sign-in $name${requested_at:+ (requested-at $requested_at)} -> $status" "$body"
if [ "$status" != 201 ]; then
    echo "サインインできなかった（状態コード $status）: $(cat "$body")" >&2
    exit 1
fi
mv "$body" "$run_dir/sessions/$name.json"
jq -r .accountId "$run_dir/sessions/$name.json"
