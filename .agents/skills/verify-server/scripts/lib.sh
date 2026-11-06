# verify-server の道具が共通で読む。単体では動かさない
# shellcheck shell=bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git -C "$script_dir" rev-parse --show-toplevel)"

# 回のフォルダの run.env を読む。BASE_URL・E2E_SIGN_IN_SECRET・PGID・REVISION が入る
load_run() {
    run_dir="${1:?回のフォルダ（start.sh が最後に出した行）を渡す}"
    [ -f "$run_dir/run.env" ] || { echo "$run_dir に run.env が無い（start.sh で立てた回のフォルダを渡す）" >&2; exit 2; }
    # shellcheck source=/dev/null
    . "$run_dir/run.env"
}

session_token() {
    local file="$run_dir/sessions/$1.json"
    [ -f "$file" ] || { echo "セッション $1 が無い（sign-in.sh $run_dir $1 で作る）" >&2; exit 2; }
    jq -r .sessionToken "$file"
}

# 送る・取りに行く要求に付ける端末の状態。1つの回を1台の端末として送る
client_state() {
    jq -n --arg deviceId "$DEVICE_ID" '{deviceId: $deviceId, timeZone: "Asia/Tokyo", appVersion: "1.0.0", osVersion: "26.0", pendingWriteCount: 1, oldestPendingWriteAgeSeconds: 0, pendingPhotoCount: 0}'
}

# 要求と応答を証拠の記録に足す
log_evidence() {
    local line="$1" body_file="$2"
    {
        printf '### %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$line"
        # 写真のような本文は、中身でなく大きさだけを残す
        if [ -s "$body_file" ] && ! grep -qI . "$body_file"; then
            printf '（バイナリ %s バイト）' "$(wc -c < "$body_file" | tr -d ' ')"
        else
            head -c 4000 "$body_file"
        fi
        printf '\n\n'
    } >> "$run_dir/evidence/requests.log"
}
