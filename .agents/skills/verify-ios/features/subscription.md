# サブスクリプションの課金画面

無料体験が終わったユーザーは、入力欄のチップから課金画面を開き、購入者のトークンを受け取ってから出る買うところで月額を買うと、撮って記録できる入力欄に戻る。課金画面の「購入を復元」の結果は、画面の上の1行に出る。

## Sub-features

- `subscription-paywall-waits-for-token` 購入者のトークンを受け取るまでは、宣伝の部分の下に読み込み中を出し、買うところを作らない
- `subscription-purchase` 買うと課金画面が閉じ、入力欄のカメラと写真が押せるようになる
- `subscription-restore` 「購入を復元」の結果の1行が、開いた直後の位置で見える

## How to get to it (user POV)

- 無料体験が終わった日のタイムラインで、入力欄の上のチップ（`composer-subscription-chip`）を押す
- タイムラインの右上のアカウント（`account`）を押し、アカウントの画面の「サブスクリプション」を押す

## Driving it with verify-ios

Preconditions:

- なし（場面が、無料体験の終わったアカウントを作る）

- **トークンを待つ。** `$S/ui-test.sh PaywallWaitsForAppAccountTokenUITests`。トークンを返さない場面で、読み込み中（`paywall-loading`）が出て、買うボタン（`paywall-purchase`）が無い
- **買う。** `$S/ui-test.sh SubscribeFromComposerChipAfterFreeTrialUITests`。買うボタンを押すと課金画面が閉じ、カメラ（`composer-capture`）が押せて、チップと「無料体験が終わりました」が消える
- **購入を復元。** `$S/ui-test.sh RestoreFromPaywallWithoutPurchaseUITests`。結果の1行（`paywall-message`）が押せる位置に出る
- **手で見るとき。** `$S/launch.sh "$run" signed-in subscription-expired` で `composer-subscription-chip` を押す。`subscription-expired-token-pending` にすると、トークンを待つ画面のままになる

## Gotchas

- UI テストと手で開く場面では、StoreKit の `SubscriptionStoreView` を出さず、月額を買うボタンだけの買うところ（`PaywallStorefront.fixed`）を出す。`SubscriptionStoreView` での本物の購入と、取引に購入者のトークンが付くかは、実機のデバッグビルド（開発用のサーバー）と Sandbox のテスト用アカウントで買い、開発用のサーバーのログの `POST /v1/subscription-transactions` の `hasAppAccountToken` で見る（`docs/agents/tooling.md` の「Cloudflare を読む」）
- Sandbox の App Store の通知は本番のサーバーに届く。開発用のサーバーが出したトークンの購入は、本番ではどのアカウントにも結びつかない（unrouted）ので、通知だけで結びつくことは実機では見られない
