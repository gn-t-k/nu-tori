#!/usr/bin/env bash
# 手元に、開発用の設定のサーバー（wrangler dev --local）を空の状態から立てる。
# 使い方: start.sh [ポート]（既定は 8799）。最後の行に回のフォルダを出す
set -euo pipefail
# shellcheck source=SCRIPTDIR/lib.sh
. "$(dirname "$0")/lib.sh"

port="${1:-8799}"
base_url="http://127.0.0.1:$port"
if curl -s -o /dev/null --max-time 2 "$base_url"; then
    echo "$base_url で何かが応答している。自分で立てた回でなければ、別のポートを渡す" >&2
    exit 1
fi

run_dir="$root/.scratch/verify-server/$(date +%Y%m%d-%H%M%S)-$port"
mkdir -p "$run_dir/evidence" "$run_dir/sessions" "$run_dir/state"

# 秘密の値はどれも手元だけの偽物。Apple と Sentry には届かない。
# 推定・読み分け・返事は Anthropic を呼ぶので、開発用のワークスペースの鍵を VERIFY_SERVER_ANTHROPIC_API_KEY で渡したときだけ動く
apple_private_key="$(openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 2> /dev/null | awk '{printf "%s\\n", $0}')"
key_of() { head -c 32 /dev/zero | tr '\0' "\\$1" | base64; }
cat > "$run_dir/dev.vars" << VARS
BETTER_AUTH_SECRET="local-verify-better-auth-secret-0123456789"
APPLE_TEAM_ID="TEAM000000"
APPLE_KEY_ID="KEY0000000"
APPLE_PRIVATE_KEY="$apple_private_key"
APPLE_REFRESH_TOKEN_KEYS="1:$(key_of 001)"
APPLE_SUB_HASH_KEYS="1:$(key_of 002)"
SENTRY_DSN=""
ANTHROPIC_API_KEY="${VERIFY_SERVER_ANTHROPIC_API_KEY:-local-verify-no-anthropic-key}"
VARS
e2e_secret="local-verify-e2e-sign-in-secret-0123456789"

cd "$root/server"
echo "D1 の移行を当てる" >&2
pnpm exec wrangler d1 migrations apply DB --local --persist-to "$run_dir/state" > "$run_dir/migrations.log" 2>&1 ||
    { tail -20 "$run_dir/migrations.log" >&2; exit 1; }

# wrangler は secrets.required の名前しか env ファイルから読まないので、確かめのサインインの秘密の値は --var で渡す
echo "wrangler dev を立てる（ログ: $run_dir/wrangler.log）" >&2
setsid pnpm exec wrangler dev --local --ip 127.0.0.1 --port "$port" \
    --persist-to "$run_dir/state" --env-file "$run_dir/dev.vars" \
    --var "E2E_SIGN_IN_SECRET:$e2e_secret" --show-interactive-dev-session=false \
    > "$run_dir/wrangler.log" 2>&1 < /dev/null &
pgid=$!

server_tree="$(server_content_hash)"
cat > "$run_dir/run.env" << ENV
BASE_URL=$base_url
E2E_SIGN_IN_SECRET=$e2e_secret
PGID=$pgid
SERVER_TREE=$server_tree
COMMIT=$(git -C "$root" rev-parse HEAD)$([ "$server_tree" = "$(git -C "$root" rev-parse HEAD:server)" ] || echo -dirty)
DEVICE_ID=$("$script_dir/uuid.sh")
ENV

for _ in $(seq 1 120); do
    if ! kill -0 "$pgid" 2> /dev/null; then
        echo "wrangler dev が止まった" >&2
        tail -30 "$run_dir/wrangler.log" >&2
        exit 1
    fi
    if grep -q "Ready on $base_url" "$run_dir/wrangler.log" &&
        [ "$(curl -s --max-time 5 "$base_url/health")" = '{"status":"ok"}' ]; then
        echo "立った: $base_url" >&2
        echo "$run_dir"
        exit 0
    fi
    sleep 1
done
echo "120 秒たっても立たなかった。stop.sh $run_dir で止める" >&2
tail -30 "$run_dir/wrangler.log" >&2
exit 1
