#!/usr/bin/env bash
# セッションを付けて API を1回呼び、本文を標準出力に、状態コードを標準エラーに出す。2xx でなければ 1 で終わる。
# 使い方: api.sh <回のフォルダ> <セッションの名前> [--e2e | --as-of <ISO 8601>] <メソッド> <パス> [curl の引数...]
#   --e2e: 確かめの口（/v1/e2e/*）が求める秘密の値のヘッダーを付ける
#   --as-of: 開発用だけの時刻の差し替え（x-e2e-requested-at）も付け、その時刻に送ったことにする（目標の設定の要求が読む）
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
load_run "${1-}"
token="$(session_token "${2:?セッションの名前を渡す}")"
shift 2
extra=()
case "${1-}" in
    --e2e)
        extra=(-H "x-e2e-sign-in-secret: $E2E_SIGN_IN_SECRET")
        shift
        ;;
    --as-of)
        extra=(-H "x-e2e-sign-in-secret: $E2E_SIGN_IN_SECRET" -H "x-e2e-requested-at: ${2:?時刻を渡す}")
        shift 2
        ;;
esac
method="${1:?メソッドを渡す}"
path="${2:?パスを渡す}"
shift 2

body="$(mktemp)"
status="$(curl -s -o "$body" -w '%{http_code}' -X "$method" -H "authorization: Bearer $token" "${extra[@]}" "$@" "$BASE_URL$path")"
log_evidence "$method $path -> $status" "$body"
cat "$body"
echo "状態コード $status" >&2
rm -f "$body"
[[ "$status" == 2* ]]
