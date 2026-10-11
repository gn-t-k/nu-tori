#!/usr/bin/env bash
# PROTOTYPE: 会話で話し手が変わるところの間を比べるために、起動中のシミュレーターでアプリを開く（#449）。main には入れない。
# 今日 7:12 に体重を記録し、昼に会話を3往復した場面で開き、画面の下のバーで A/B/C を切り替える。
# 使い方: ios/prototype-conversation-gap.sh [シミュレーターの UDID]（省略すると起動中のもの）
set -euo pipefail
cd "$(dirname "$0")"
SIM="${1:-booted}"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/nu-tori-prototype-conversation-gap"
xcodebuild -project NuTori.xcodeproj -scheme NuTori -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" -quiet build
xcrun simctl install "$SIM" "$DERIVED/Build/Products/Debug-iphonesimulator/NuTori.app"
SIMCTL_CHILD_PROTOTYPE_CONVERSATION_GAP=1 \
  SIMCTL_CHILD_UI_TEST_ACCOUNT=signed-in \
  SIMCTL_CHILD_UI_TEST_API=prototype-conversation-gap \
  SIMCTL_CHILD_UI_TEST_NOW=2026-10-11T13:00 \
  xcrun simctl launch --terminate-running-process "$SIM" app.nu-tori
