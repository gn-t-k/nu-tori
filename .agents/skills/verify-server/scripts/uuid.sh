#!/usr/bin/env bash
# 記録の ID に使う、小文字の正規形の UUID を1つ出す（サーバーは大文字の綴りを断る）
set -euo pipefail
cat /proc/sys/kernel/random/uuid 2> /dev/null || uuidgen | tr '[:upper:]' '[:lower:]'
