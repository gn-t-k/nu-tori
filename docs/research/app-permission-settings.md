# アプリから許可の設定をどこまで見せ、開けるか

調査日: 2026-09-24
対象: `docs/ui-design/0001-first-release/` の ⑥ アカウントに置く、ヘルスケア・通知・カメラの許可の扱い（`06-layout.md` の「各ビューの出し方とアカウントの入口」）

> **確認の方法と限界**
> - Apple Human Interface Guidelines（以下 HIG）と開発者向けドキュメントは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（`https://developer.apple.com/tutorials/data/<パス>.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 本文を探しても記述が無かったものは「本文を探したが記述なし」と書き、探したページを添える。
> - 実機での確認はしていない。二次情報（ブログ、記事、SNS）は使っていない。

## 結論の要約

- ヘルスケアの共有は、iPhone の設定とヘルスケアアプリで管理する。アプリの中に、データの流れを変える画面を作らない（本文で確認）
- 読み取りを許可されたかどうかは、アプリから分からない（本文で確認）
- ヘルスケアの共有の設定を、アプリから直接開く手段は、調べた4ページには書かれていない（本文を探したが記述なし）。行き方を文で示すにとどめる
- 通知は、iPhone の設定にある、このアプリの通知の設定を直接開ける（本文で確認、iOS 16 から）
- openSettingsURLString が開くのは、このアプリ独自の設定（あれば）。カメラの切り替えもそこに出ると見込むが、本文に記述はなく、実機で確かめる

## 根拠

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| ヘルスケアの共有をアプリの中で変えてよいか | 「ヘルスケアのデータの共有は、システムのプライバシー設定だけで管理する」「データの流れに関わる画面をアプリに足して、人を迷わせない」（"Manage health data sharing solely through the system's privacy settings." "Don't confuse people by building additional screens in your app that affect the flow of health data."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/healthkit |
| どこで管理すると思われているか | 「人は、ヘルスケアの情報へのアクセスを、設定 > プライバシー でまとめて管理すると思っている」（"People expect to globally manage access to their health information in Settings > Privacy."） | 本文で確認 | 同上 |
| ヘルスケアアプリからも変えられるか | 「このアプリへの許可は、設定アプリかヘルスケアアプリで、いつでも変えられる」（"A person can change the permissions for your app at any time using either the Settings or Health app."） | 本文で確認 | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data |
| 今の iOS での設定の場所の名前 | 同じページに、設定の「Privacy and Security」のパネルという記述がある。日本語の表示（「プライバシーとセキュリティ」）と、その先の画面の並びは本文にない。画面の文言は ⑦ で決め、行き方は実機で確かめる | 前半は本文で確認、後半は本文を探したが記述なし | 同上 |
| 読み取りの許可の状態 | 読み取りを許可されたか拒否されたかは、アプリには分からない。authorizationStatus(for:) が示すのは書き込み（共有）の状態だけ | 本文で確認（`docs/research/hig-inline-goal-setup.md` で確認済み） | 同上、https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:) |
| アプリから開ける設定のページ | openSettingsURLString は「設定アプリの中の、このアプリ独自の設定へ深くリンクする URL。独自の設定があれば、それを表示する」（"deep link to your app's custom settings … display your app's custom settings, if it has any"） | 本文で確認 | https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring |
| カメラの切り替えはどこにあるか | openSettingsURLString のページに、カメラなどの許可の切り替えについての記述はない。開いた先に並ぶかは実機で確かめる | 本文を探したが記述なし | 同上 |
| 通知の設定を直接開けるか | openNotificationSettingsURLString は「設定アプリの中の、このアプリの通知の設定へ深くリンクする URL」。iOS 16 から使える | 本文で確認 | https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring |
| ヘルスケアの共有の設定を直接開けるか | HealthKit の HIG、Authorizing access to health data、openSettingsURLString、openNotificationSettingsURLString の4ページに、ヘルスケアの共有の設定を開く手段の記述はない | 本文を探したが記述なし | 上の4ページ |
| ヘルスケアの呼び方 | 画面の文では「Apple Health」または「Apple Health app」と呼ぶ。「HealthKit」と書かない。端末に表示される訳語を使う | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/healthkit |

## アカウントへの当てはめ

- **ヘルスケア**: 許可の状態は出さない。読み取る種類と書き込む種類を並べ、変えるときは iPhone の設定かヘルスケアアプリで変えられることを文で示す。切り替えのスイッチも、開くボタンも置かない（本文からの読み取り）
- **通知**: 許可の状態を出し、変えるときは openNotificationSettingsURLString で通知の設定を開く（本文からの読み取り）
- **カメラ**: 許可の状態を出し、変えるときは openSettingsURLString で開く。カメラの切り替えがそこに出るかは実機で確かめる（本文からの読み取り）
