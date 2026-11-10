#!/usr/bin/env bash
# UI テストを scripts/check ios-ui-test --only で回し、結果（xcresult、テストごとの結果、確かめた画面）を新しい回のフォルダに写す。
# 使い方: ui-test.sh <クラス>[/<メソッド>]...。最後の行に回のフォルダを出し、落ちたテストがあれば 1 で終わる
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
if [ $# -eq 0 ]; then
    sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
fi

new_run_dir ui-test
ios_tree="$(ios_content_hash)"
cat > "$run_dir/run.env" << ENV
IOS_TREE=$ios_tree
COMMIT=$(commit_of_tree "$ios_tree")
ENV
only=()
for test in "$@"; do only+=(--only "$test"); done

echo "UI テストを回す（ログ: $run_dir/ui-test.log）" >&2
status=0
"$root/scripts/check" ios-ui-test "${only[@]}" > "$run_dir/ui-test.log" 2>&1 || status=$?

results="$root/ios/.build/NuTori.xcresult"
if [ ! -d "$results" ] || [ "$results" -ot "$run_dir/run.env" ]; then
    echo "UI テストの前で止まった（xcresult が無い）" >&2
    tail -30 "$run_dir/ui-test.log" >&2
    echo "$run_dir"
    exit 1
fi
cp -R "$results" "$run_dir/evidence/"
xcrun xcresulttool get test-results tests --path "$results" > "$run_dir/evidence/tests.json"
xcrun xcresulttool export attachments --path "$results" --output-path "$run_dir/evidence/attachments" > /dev/null
# テストごとの結果を1行ずつ出す
jq -r '.. | objects | select(.nodeType? == "Test Case") | "\(.result)  \(.nodeIdentifier // .name)"' \
    "$run_dir/evidence/tests.json" | tee "$run_dir/evidence/summary.txt" >&2
echo "$run_dir"
exit "$status"
