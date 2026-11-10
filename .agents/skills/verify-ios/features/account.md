# サインインとアカウント

初めて開いたユーザーは、説明のひとことと同意のカードを読み、Apple でサインインしてタイムラインに入る。アカウントの画面からサインアウトするとサインインし直しの画面に、アカウントを削除するとサインインの画面に戻る。

## Sub-features

- `account-sign-in` Apple でサインインすると、サインインの画面がタイムラインに置き換わり、戻れない
- `account-sign-in-failed` サインインを取り消すと画面はそのまま、失敗すると理由の1行が出る
- `account-sign-out` アカウントの画面のサインアウトで、サインインし直しの画面に戻る
- `account-delete` アカウントの画面のアカウントを削除で、確かめてからサインインの画面に戻る

## How to get to it (user POV)

- 初めて開く。サインインの画面の「Apple でサインイン」（`appleSignInButton`）を押す
- タイムラインの左上のアカウント（`account`）を押し、アカウントの画面の下の「サインアウト」を押す
- アカウントの画面のいちばん下の「アカウントを削除」を押し、確かめの「アカウントを削除」を押す

## Driving it with verify-ios

Preconditions:

- なし（場面が、サインインしていない・サインイン済みのアカウントを作る）

- **サインインの画面。** `$S/ui-test.sh SignInFirstLaunchUITests` の `test_説明のひとことと同意のカードとAppleのボタンが出ること`。「毎朝の体重と、食事の写真だけ。」と「続ける前に」、利用規約とプライバシーポリシーのリンク、Apple のボタンが出て、タイムラインは出ない
- **サインイン。** 同じクラスの `test_サインインするとタイムラインに置き換わり戻れないこと`。ボタンを押すとタイムライン（`timeline`）とアカウントのボタンが出て、サインインの画面と戻るボタンが無い
- **取り消す・失敗する。** `$S/ui-test.sh SignInAppleCancelledUITests SignInAppleFailedUITests`。取り消すとサインインの画面のまま何も出ず、失敗すると「サインインできませんでした。もう一度押してください。」が出て、どちらも Apple のボタンを押せる
- **サインアウト。** `$S/ui-test.sh SignOutWithoutPendingWritesUITests`。サインインの画面に戻り、「もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。」が出る
- **削除。** `$S/ui-test.sh DeleteAccountUITests`。確かめのあと、サインインの画面（`signIn`）に戻り、タイムラインが無い
- **手で見るとき。** `$S/launch.sh "$run" signed-out online` でサインインの画面、`$S/launch.sh "$run" signed-in online` で `account` を押してアカウントの画面を開く

## Gotchas

- Apple の結果は起動の値（`UI_TEST_APPLE_SIGN_IN`）で差し替えるので、本物の Sign in with Apple は通らない。サインインの入口を変えた PR は、本物を「確かめていない」と書き、TestFlight の版で確かめる
- 削除で本当にサーバーの記録が消えるかは、偽の同期サーバーでは分からない。サーバーの側は `verify-server` の [サインインとアカウントの削除](../../verify-server/features/account.md) で確かめる
- 「アカウントを削除」は一覧のいちばん下にあり、画面の外では要素が作られない。手で動かすときは、`snapshot_ui` で見つかるまで上へ送る
