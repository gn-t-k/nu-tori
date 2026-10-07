#!/usr/bin/env bash
# [DEBUG-354] #354 を調べるための見張り。マージしない
# 使い方: watch.sh <xcodebuild の出力を写したログ> <書き出す先>
# - 5 秒ごとに、ランナーの負荷を load.txt に残す
# - 「Terminate app.nu-tori:<pid>」が出て 8 秒たってもその pid が居れば、ps・sample・spindump と、
#   シミュレータの中の終わらせる係（runningboardd など）のログを stuck-<pid>/ に残す
set -uo pipefail
log="$1" out="$2"
mkdir -p "$out"

(
    while true; do
        {
            echo "== $(date '+%T')"
            uptime
            memory_pressure 2> /dev/null | tail -1
            ps -axo pid,stat,%cpu,rss,comm -r | head -8
        } >> "$out/load.txt" 2>&1
        sleep 5
    done
) &

capture() {
    local pid="$1" dir="$out/stuck-$1"
    sleep 8
    kill -0 "$pid" 2> /dev/null || return 0
    mkdir -p "$dir"
    local udid
    udid="$(xcrun simctl list devices booted -j | jq -r '.devices[][] | select(.name | startswith("nu-tori ui-test ")) | .udid' | head -1)"
    {
        echo "== $(date '+%F %T') pid $pid still alive 8s after Terminate (simulator $udid)"
        ps -o pid,ppid,stat,%cpu,%mem,rss,etime,wchan,command -p "$pid"
        echo "== children/parents"; ps -axo pid,ppid,stat,command | awk -v p="$pid" '$1==p || $2==p'
        echo "== load"; uptime; memory_pressure | tail -3
        echo "== top cpu"; ps -axo pid,stat,%cpu,rss,comm -r | head -20
    } > "$dir/ps.txt" 2>&1
    sample "$pid" 3 -file "$dir/sample.txt" > /dev/null 2>&1
    sudo -n spindump "$pid" 3 -file "$dir/spindump.txt" > /dev/null 2>&1
    if [ -n "$udid" ]; then
        xcrun simctl spawn "$udid" log show --last 90s --style compact \
            --predicate 'process == "NuTori" OR process == "runningboardd" OR process == "SpringBoard" OR process == "testmanagerd" OR subsystem == "com.apple.runningboard"' \
            > "$dir/simlog.txt" 2>&1
    fi
    sleep 20
    { echo "== +20s $(date '+%T')"; ps -o pid,stat,%cpu,etime,command -p "$pid"; } >> "$dir/ps.txt" 2>&1
    sample "$pid" 3 -file "$dir/sample2.txt" > /dev/null 2>&1
}

touch "$log"
tail -n0 -F "$log" 2> /dev/null | while IFS= read -r line; do
    if [[ "$line" =~ Terminate\ app\.nu-tori:([0-9]+) ]]; then
        capture "${BASH_REMATCH[1]}" &
    fi
done
