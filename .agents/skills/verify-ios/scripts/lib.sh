# verify-ios の道具が共通で読む。単体では動かさない
# shellcheck shell=bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git -C "$script_dir" rev-parse --show-toplevel)"
# scripts/check と MobileBuildMCP（.mobilebuildmcp/config.yaml）と同じ置き場。同じ worktree で同時に組むと、あとのほうが build.db のロックで落ちる
derived_data="$root/ios/.build/DerivedData"
app_path="$derived_data/Build/Products/Debug-iphonesimulator/NuTori.app"
bundle_id="app.nu-tori"

# 回のフォルダの run.env を読む。UDID（この回が作ったシミュレーター）・COMMIT（組んだときのコミット）・IOS_TREE（そのときの ios/）が入る
load_run() {
    run_dir="${1:?回のフォルダ（start.sh が最後に出した行）を渡す}"
    [ -f "$run_dir/run.env" ] || { echo "$run_dir に run.env が無い（start.sh か ui-test.sh で作った回のフォルダを渡す）" >&2; exit 2; }
    # shellcheck source=/dev/null
    . "$run_dir/run.env"
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

# 組んだコミット。ios/ に作業中の変更があれば -dirty を付ける
commit_of_tree() {
    echo "$(git -C "$root" rev-parse HEAD)$([ "$1" = "$(git -C "$root" rev-parse HEAD:ios)" ] || echo -dirty)"
}

# この回のシミュレーターでアプリが動いているか
app_running() {
    xcrun simctl spawn "$UDID" launchctl list 2> /dev/null | grep -q "UIKitApplication:$bundle_id"
}
