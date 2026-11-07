#!/usr/bin/env bash
# 端末の代わりに要求を送る（server/e2e/cli/drive-device.ts を呼ぶ）。引数なしで使い方を出す。
#   device.sh uuid
#   device.sh sign-in <回のフォルダ> <名前> [--as-of <ISO 8601>]
#   device.sh push <回のフォルダ> <名前> '<書き込みの JSON の配列>'
#   device.sh pull <回のフォルダ> <名前> [--after <sequence>]
#   device.sh call <回のフォルダ> <名前> <メソッド> <パス> [--e2e] [--as-of <ISO 8601>] [--json <本文>] [--body-file <パス> --content-type <型>] [--out <パス>] [--timeout <秒>]
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
# 呼んだ場所のまま動かす（--body-file などの相対パスを、呼んだ場所から読むため）
exec "$root/server/node_modules/.bin/tsx" "$root/server/e2e/cli/drive-device.ts" "$@"
