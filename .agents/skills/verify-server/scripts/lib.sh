# verify-server の道具が共通で読む。単体では動かさない
# shellcheck shell=bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git -C "$script_dir" rev-parse --show-toplevel)"

# 回のフォルダの run.env を読む。BASE_URL・E2E_SIGN_IN_SECRET・PGID・COMMIT（立てたときのコミット）・SERVER_TREE（そのときの server/）・DEVICE_ID が入る
load_run() {
    run_dir="${1:?回のフォルダ（start.sh が最後に出した行）を渡す}"
    [ -f "$run_dir/run.env" ] || { echo "$run_dir に run.env が無い（start.sh で立てた回のフォルダを渡す）" >&2; exit 2; }
    # shellcheck source=/dev/null
    . "$run_dir/run.env"
}

# server/ の今の中身（作業中の変更と、追跡していない新しいファイルを含む）のハッシュ。gitignore したもの（node_modules など）は入らない
server_content_hash() {
    local index
    index="$(mktemp)"
    GIT_INDEX_FILE="$index" git -C "$root" read-tree HEAD
    GIT_INDEX_FILE="$index" git -C "$root" add -A server
    git -C "$root" rev-parse "$(GIT_INDEX_FILE="$index" git -C "$root" write-tree):server"
    rm -f "$index"
}
