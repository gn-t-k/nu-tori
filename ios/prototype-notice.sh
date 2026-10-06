#!/usr/bin/env bash
# PROTOTYPE: 体重の知らせの見せ方を比べるために、起動中のシミュレーターでアプリを開く。main には入れない。
# おととい記録・昨日は答えていない知らせ・今日 9:00 で未記録、の場面で開き、画面の下のバーで A/B/C を切り替える。
# 使い方: ios/prototype-notice.sh [シミュレーターの UDID]（省略すると起動中のもの）
set -euo pipefail
cd "$(dirname "$0")"
SIM="${1:-booted}"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/nu-tori-prototype-notice"
xcodebuild -project NuTori.xcodeproj -scheme NuTori -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" -quiet build
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/NuTori.app"
SIMCTL_CHILD_PROTOTYPE_NOTICE=1 \
  SIMCTL_CHILD_UI_TEST_ACCOUNT=signed-in \
  SIMCTL_CHILD_UI_TEST_API=prototype-notice \
  SIMCTL_CHILD_UI_TEST_NOW=2026-10-05T09:00 \
  xcrun simctl launch --terminate-running-process "$SIM" app.nu-tori
