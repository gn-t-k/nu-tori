#!/usr/bin/env bash
# UI テストを scripts/check ios-ui-test --only で回し、結果（xcresult、テストごとの結果、確かめた画面）を新しい回のフォルダに写す。
# 最後の行に回のフォルダを出し、落ちたテストがあれば 1 で終わる。引数なしで使い方を出す
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
if [ $# -eq 0 ]; then
    echo "使い方: ui-test.sh <クラス>[/<メソッド>]..." >&2
    exit 2
fi

new_run_dir ui-test
record_built_tree
only=()
for test in "$@"; do only+=(--only "$test"); done

echo "UI テストを回す（ログ: $run_dir/ui-test.log）" >&2
status=0
"$root/scripts/check" ios-ui-test "${only[@]}" > "$run_dir/ui-test.log" 2>&1 || status=$?

# scripts/check の check_ios_ui_test が書く置き場
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
# 名前の誤りや、空白を含む1つの引数（zsh は変数を分けない）では、xcodebuild は0件で成功する
if [ ! -s "$run_dir/evidence/summary.txt" ]; then
    echo "回ったテストが0件だった。クラスの名前と、引数を1つずつ渡しているかを見る" >&2
    status=1
fi
echo "$run_dir"
exit "$status"
