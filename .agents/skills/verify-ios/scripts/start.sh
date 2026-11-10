#!/usr/bin/env bash
# この回だけのシミュレーターを作って起動し、アプリ（デバッグビルド）を組んで入れる。開くのは launch.sh。
# 使い方: start.sh。最後の行に回のフォルダを出す
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"

command -v xcodebuild > /dev/null || { echo "verify-ios は macOS でだけ動く" >&2; exit 1; }

# 機種とランタイムは、scripts/check の UI テストと同じ端末（latest_iphone_simulator と同じ選び方）にそろえ、組んだものを使い回す
latest="$(xcrun simctl list devices available | awk '
    /^-- iOS / { ios = 1; picked = 0; next }
    /^-- / { ios = 0; next }
    ios && !picked && /^ +iPhone/ && !/^ +iPhone Duo / {
        match($0, /\([0-9A-F-]{36}\)/)
        latest = substr($0, RSTART + 1, 36)
        picked = 1
    }
    END { print latest }
')"
read -r device_type runtime < <(xcrun simctl list devices -j | jq -r --arg id "$latest" \
    '.devices | to_entries[] | .key as $runtime | .value[] | select(.udid == $id) | "\(.deviceTypeIdentifier) \($runtime)"') || true
if [ -z "${device_type-}" ] || [ -z "${runtime-}" ]; then
    echo "iPhone のシミュレーターが無い" >&2
    exit 1
fi

new_run_dir sim
name="nu-tori verify-ios $(basename "$run_dir")"
# 共有の iPhone（MobileBuildMCP と Xcode が使う）と UI テストの複製は使わない。取り合わないよう、この回だけの端末を作る
udid="$(xcrun simctl create "$name" "$device_type" "$runtime")"
echo "UDID=$udid" > "$run_dir/run.env"
echo "シミュレーター「${name}」を作った。失敗しても stop.sh $run_dir で消す" >&2

xcrun simctl bootstatus "$udid" -b > "$run_dir/boot.log" 2>&1 ||
    { tail -20 "$run_dir/boot.log" >&2; exit 1; }

echo "アプリを組む（ログ: $run_dir/build.log）" >&2
ios_tree="$(ios_content_hash)"
xcodebuild \
    -project "$root/ios/NuTori.xcodeproj" \
    -scheme NuTori \
    -destination "id=$udid" \
    -derivedDataPath "$derived_data" \
    -disableAutomaticPackageResolution \
    build > "$run_dir/build.log" 2>&1 ||
    { grep -E 'error:|BUILD FAILED|database is locked' "$run_dir/build.log" | tail -20 >&2; exit 1; }
xcrun simctl install "$udid" "$app_path"

cat >> "$run_dir/run.env" << ENV
IOS_TREE=$ios_tree
COMMIT=$(commit_of_tree "$ios_tree")
ENV
echo "組んで入れた。launch.sh $run_dir <アカウント> <API の場面> で開く" >&2
echo "$run_dir"
