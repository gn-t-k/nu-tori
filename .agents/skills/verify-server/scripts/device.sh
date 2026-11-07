#!/usr/bin/env bash
# 端末の代わりに要求を送る（server/e2e/cli/drive-device.ts を呼ぶ）。引数なしで使い方を出す。
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"
# 呼んだ場所のまま動かす（--body-file などの相対パスを、呼んだ場所から読むため）
exec "$root/server/node_modules/.bin/tsx" "$root/server/e2e/cli/drive-device.ts" "$@"
