#!/bin/bash
# プレビューとスナップショットまわりの未確認の点を、開発者の Mac で試す（使い捨て）
#   experiments/preview-lab/run-on-mac.sh            自動で確かめられるものを回す（5〜10 分）
#   experiments/preview-lab/run-on-mac.sh --network  上に加えて、回線の絞りがシミュレータに効くかも試す（sudo が要る）
# 結果は out/ に書く。終わったら out/ をコミットして push する（手順は最後に出る）
set -u
cd "$(dirname "$0")"
LAB="$PWD"
OUT="$LAB/out"
rm -rf "$OUT" "$LAB/dd" "$LAB/Tests/__Snapshots__"
mkdir -p "$OUT"
S="$OUT/summary.md"
NETWORK=0
[ "${1:-}" = "--network" ] && NETWORK=1
section() { echo; echo "## $1" | tee -a "$S"; }
run() { echo "\$ $*" | tee -a "$S"; ( "$@" ) 2>&1 | tail -n "${TAIL:-40}" | tee -a "$S"; echo "exit=${PIPESTATUS[0]}" | tee -a "$S"; }

section "環境"
run xcodebuild -version
run sw_vers -productVersion
run bash -c "xcrun simctl list runtimes"
run bash -c "xcrun simctl privacy 2>&1 | head -60"

section "シミュレータを用意する"
eval "$(python3 - <<'PY'
import json, subprocess
d = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j"]))
rts = [r for r in d["runtimes"] if r["isAvailable"] and r["platform"] == "iOS"]
rts.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
types = [t for t in d["devicetypes"] if t.get("productFamily") == "iPhone"]
def pick(rt, prefer):
    supported = {t["identifier"] for t in rt.get("supportedDeviceTypes", [])}
    for p in prefer:
        for t in types:
            if t["name"] == p and t["identifier"] in supported: return t
    return [t for t in types if t["identifier"] in supported][-1]
latest = rts[-1]
a = pick(latest, ["iPhone 17", "iPhone 16"])
b = pick(latest, ["iPhone 17 Pro Max", "iPhone 16 Pro Max", "iPhone Air"])
old = [r for r in rts if r["version"].startswith("26")]
print(f'RT_A="{latest["identifier"]}"; TYPE_A="{a["identifier"]}"; NAME_A="{a["name"]} iOS {latest["version"]}"')
print(f'TYPE_B="{b["identifier"]}"; NAME_B="{b["name"]} iOS {latest["version"]}"')
if old:
    o = old[-1]; c = pick(o, [a["name"]])
    print(f'RT_C="{o["identifier"]}"; TYPE_C="{c["identifier"]}"; NAME_C="{c["name"]} iOS {o["version"]}"')
else:
    print('RT_C=""; NAME_C="なし（iOS 26 のランタイムが無い）"')
PY
)"
SIM_A=$(xcrun simctl create preview-lab-a "$TYPE_A" "$RT_A")
SIM_B=$(xcrun simctl create preview-lab-b "$TYPE_B" "$RT_A")
SIM_C=""
[ -n "$RT_C" ] && SIM_C=$(xcrun simctl create preview-lab-c "$TYPE_C" "$RT_C")
cleanup_sims() { for s in "$SIM_A" "$SIM_B" "$SIM_C"; do [ -n "$s" ] && xcrun simctl delete "$s" 2>/dev/null; done; }
echo "A=$NAME_A B=$NAME_B C=$NAME_C" | tee -a "$S"

section "ビルド（#Preview(arguments:) を iOS 26 向け・Swift 6 でコンパイルできるか）"
if ! command -v xcodegen >/dev/null; then
  echo "xcodegen が無い。brew install xcodegen で入れてから、もう一度回す" | tee -a "$S"; cleanup_sims; exit 1
fi
run xcodegen generate
TAIL=60 run xcodebuild build-for-testing -project PreviewLab.xcodeproj -scheme PreviewLab \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$LAB/dd" -quiet
XCTESTRUN=$(ls "$LAB"/dd/Build/Products/*.xctestrun 2>/dev/null | head -1)
if [ -z "$XCTESTRUN" ]; then echo "ビルドに失敗した。上のエラーを見る" | tee -a "$S"; cleanup_sims; exit 1; fi

t() { # t <sim> <only-testing> <env...>
  local sim="$1" only="$2"; shift 2
  env "$@" xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "id=$sim" \
    -only-testing:"PreviewLabTests/$only" 2>&1 |
    grep -E "error:|failed|passed|LAB_NET|does not match|precision|TEST (EXECUTE )?(SUCCEEDED|FAILED)" | head -40
}

section "swift-snapshot-testing: A で撮る → A・B・C で比べる"
echo "### A で撮る" | tee -a "$S"; t "$SIM_A" SnapshotStabilityTests TEST_RUNNER_LAB_RECORD=1 | tee -a "$S"
cp -R Tests/__Snapshots__ "$OUT/reference-snapshots" 2>/dev/null
for i in 1 2; do echo "### A で比べる（$i 回目）" | tee -a "$S"; t "$SIM_A" SnapshotStabilityTests TEST_RUNNER_SNAPSHOT_ARTIFACTS="$OUT/artifacts-a" | tee -a "$S"; done
echo "### B（別の機種）で比べる" | tee -a "$S"; t "$SIM_B" SnapshotStabilityTests TEST_RUNNER_SNAPSHOT_ARTIFACTS="$OUT/artifacts-b" | tee -a "$S"
if [ -n "$SIM_C" ]; then echo "### C（iOS 26）で比べる" | tee -a "$S"; t "$SIM_C" SnapshotStabilityTests TEST_RUNNER_SNAPSHOT_ARTIFACTS="$OUT/artifacts-c" | tee -a "$S"; fi

section "ImageRenderer で List を描けるか"
t "$SIM_A" ImageRendererTests TEST_RUNNER_LAB_OUT="$OUT" | tee -a "$S"

section "SnapshotPreviews: どのプレビューを見つけ、trait を当てるか"
mkdir -p "$OUT/snapshotpreviews"
t "$SIM_A" LabPreviewSnapshots TEST_RUNNER_SNAPSHOTS_EXPORT_DIR="$OUT/snapshotpreviews" | tee -a "$S"
ls "$OUT/snapshotpreviews" | tee -a "$S"

section "simctl privacy でヘルスケアの権限を与えられるか"
xcrun simctl boot "$SIM_A" 2>/dev/null
run xcrun simctl install "$SIM_A" "$LAB/dd/Build/Products/Debug-iphonesimulator/PreviewLab.app"
for svc in health healthkit; do run xcrun simctl privacy "$SIM_A" grant "$svc" dev.nutori.lab.PreviewLab; done

if [ "$NETWORK" = 1 ]; then
  section "Mac の回線の絞り（dnctl・pf）がシミュレータに効くか（example.com への TCP だけ）"
  IPS=$(python3 -c "import socket;print(', '.join(sorted({a[4][0] for a in socket.getaddrinfo('example.com',443,proto=socket.IPPROTO_TCP)})))")
  echo "example.com: $IPS" | tee -a "$S"
  # 途中で止めても、絞りを必ず外す
  restore_network() { sudo pfctl -a com.apple/preview-lab -F all >/dev/null 2>&1; sudo dnctl -q flush >/dev/null 2>&1; }
  trap 'restore_network; cleanup_sims' EXIT
  probe() { t "$SIM_A" NetworkProbeTests TEST_RUNNER_LAB_OUT="$OUT" TEST_RUNNER_LAB_NET_LABEL="$1" | grep LAB_NET | tee -a "$S"; }
  probe baseline
  sudo pfctl -E 2>&1 | tail -1 | tee -a "$S"
  sudo dnctl pipe 1 config delay 1500
  echo "dummynet out proto tcp from any to { $IPS } pipe 1" | sudo pfctl -a com.apple/preview-lab -f - 2>&1 | tee -a "$S"
  probe delay1500ms
  echo "block drop out quick proto tcp from any to { $IPS }" | sudo pfctl -a com.apple/preview-lab -f - 2>&1 | tee -a "$S"
  probe blocked
  restore_network
  probe restored
else
  cleanup_sims
fi

section "おわり"
echo "out/summary.md と画像ができた。次に CHECKLIST.md の手で確かめる項目をやり、結果を out/manual.md に書いてから:" | tee -a "$S"
echo "  git add -f experiments/preview-lab/out && git commit -m 'プレビューの試しの結果を置く' && git push" | tee -a "$S"
