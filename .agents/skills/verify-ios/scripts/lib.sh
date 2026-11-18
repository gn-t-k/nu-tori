# verify-ios の道具が共通で読む。単体では動かさない
# shellcheck shell=bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git -C "$script_dir" rev-parse --show-toplevel)"
# scripts/check と MobileBuildMCP（.mobilebuildmcp/config.yaml）と同じ置き場。同じ worktree で同時に組むと、あとのほうが build.db のロックで落ちる
derived_data="$root/ios/.build/DerivedData"
app_path="$derived_data/Build/Products/Debug-iphonesimulator/NuTori.app"
bundle_id="app.nu-tori"

# start.sh で作った回のフォルダの run.env を読む。UDID（この回が作ったシミュレーター）・COMMIT（組んだときのコミット）・IOS_TREE（そのときの ios/）・BUILT（組んで入れ終えた印）が入る
load_run() {
    run_dir="${1:?回のフォルダ（start.sh が最後に出した行）を渡す}"
    [ -f "$run_dir/run.env" ] || { echo "$run_dir に run.env が無い（start.sh で作った回のフォルダを渡す）" >&2; exit 2; }
    # shellcheck source=/dev/null
    . "$run_dir/run.env"
    # ui-test.sh の回は端末を持たない（UI テストの端末は scripts/check が作って消す）
    [ -n "${UDID-}" ] || { echo "$run_dir は端末を持たない回（ui-test.sh の回）。手で動かす道具には start.sh で作った回を渡す" >&2; exit 2; }
}

# 新しい回のフォルダを作って run_dir に入れる。名前の後ろに付ける語を渡す
new_run_dir() {
    run_dir="$root/.scratch/verify-ios/$(date +%Y%m%d-%H%M%S)-$1"
    mkdir -p "$run_dir/evidence"
}

# ios/ の今の中身（作業中の変更と、追跡していない新しいファイルを含む）のハッシュ。gitignore したもの（.build など）は入らない
ios_content_hash() {
    local index
    index="$(mktemp)"
    GIT_INDEX_FILE="$index" git -C "$root" read-tree HEAD
    GIT_INDEX_FILE="$index" git -C "$root" add -A ios
    git -C "$root" rev-parse "$(GIT_INDEX_FILE="$index" git -C "$root" write-tree):ios"
    rm -f "$index"
}

# 確かめる ios/ の中身（IOS_TREE）と、そのときのコミット（COMMIT。ios/ に作業中の変更があれば -dirty を付ける）を run.env に足す
record_built_tree() {
    local tree
    tree="$(ios_content_hash)"
    cat >> "$run_dir/run.env" << ENV
IOS_TREE=$tree
COMMIT=$(git -C "$root" rev-parse HEAD)$([ "$tree" = "$(git -C "$root" rev-parse HEAD:ios)" ] || echo -dirty)
ENV
}

# この回のシミュレーターでアプリが動いているか
# pipefail のもとで grep -q に流すと、見つけた時点で閉じられた launchctl が SIGPIPE で落ち、見つけても失敗になるので、出力を受け取ってから比べる
app_running() {
    [[ "$(xcrun simctl spawn "$UDID" launchctl list 2> /dev/null)" == *"UIKitApplication:$bundle_id"* ]]
}
