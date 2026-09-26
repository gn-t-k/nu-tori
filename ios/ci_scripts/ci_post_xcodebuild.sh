#!/usr/bin/env bash
# Xcode Cloud が xcodebuild のあとに呼ぶ。アーカイブの dSYM を Sentry に上げる
set -euo pipefail

main() {
    if [ "$CI_XCODEBUILD_ACTION" != archive ] || [ "$CI_XCODEBUILD_EXIT_CODE" != 0 ]; then
        exit 0
    fi
    if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
        echo "warning: SENTRY_AUTH_TOKEN が無いので、dSYM を Sentry に上げない" >&2
        exit 0
    fi

    local sentry_cli_version=3.8.0
    local sentry_cli_sha256=2c26914636c47ab9bf9e710484ad7b44d371cbec8bd29cafb36b3cf877bf4285
    local dir sentry_cli
    dir=$(mktemp -d)
    sentry_cli="$dir/sentry-cli"
    curl -fsSL -o "$sentry_cli" \
        "https://github.com/getsentry/sentry-cli/releases/download/$sentry_cli_version/sentry-cli-Darwin-universal"
    echo "$sentry_cli_sha256  $sentry_cli" | shasum -a 256 -c -
    chmod +x "$sentry_cli"

    # 組織とリージョンの URL は SENTRY_AUTH_TOKEN（組織のトークン）が持つ
    "$sentry_cli" debug-files upload --type dsym --project "$SENTRY_PROJECT" "$CI_ARCHIVE_PATH"
}

main
