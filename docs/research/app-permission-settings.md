# アプリから許可の設定をどこまで見せ、開けるか

調べた日: 2026-09-24
対象: `docs/ui-design/0001-first-release/` のアカウントにある、ヘルスケア・通知・カメラの許可の扱い

## 結論

- ヘルスケアの共有は、iPhone の設定（プライバシー）だけで管理する。アプリの中に、データの流れを変える画面を作らない
- 読み取りを許可されたかどうかは、アプリから分からない。アカウントに「許可されています」とは出せない
- ヘルスケアの共有の設定を、アプリから直接開く URL は、Apple のドキュメントに見当たらない。行き方を文で案内するにとどめる
- 通知は、iPhone の設定にあるこのアプリの通知のページを、アプリから直接開ける
- アプリから開けるのは、iPhone の設定にあるこのアプリのページまで。カメラの切り替えもこのページにある（ドキュメントは「アプリの設定」とだけ書いている）

## 根拠

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| ヘルスケアの共有をアプリの中で変えてよいか | 「ヘルスケアのデータの共有は、システムのプライバシー設定だけで管理する」「データの流れに関わる画面をアプリに足して、人を迷わせない」（"Manage health data sharing solely through the system's privacy settings." "Don't confuse people by building additional screens in your app that affect the flow of health data."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/healthkit |
| どこで管理すると思われているか | 「人は、ヘルスケアの情報へのアクセスを、設定 > プライバシー でまとめて管理すると思っている」 | 本文で確認 | 同上 |
| 読み取りの許可の状態 | 読み取りを許可されたか拒否されたかは、アプリには分からない。authorizationStatus(for:) が示すのは書き込み（共有）の状態だけ | 本文で確認（`docs/research/hig-inline-goal-setup.md` で確認済み） | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data |
| アプリから開ける設定のページ | openSettingsURLString は「設定アプリの、このアプリのページへ深くリンクする URL」 | 本文で確認 | https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring |
| 通知の設定を直接開けるか | openNotificationSettingsURLString は「設定アプリの、このアプリの通知の設定へ深くリンクする URL」 | 本文で確認 | https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring |
| ヘルスケアの共有の設定を直接開けるか | HealthKit の HIG と上の2つの URL のドキュメントに、ヘルスケアの共有の設定を開く手段の記述はない | 本文を探したが記述なし | 上の3ページ |
| カメラの切り替えはどこにあるか | このアプリのページに、許可を求めた項目（カメラなど）の切り替えが並ぶ。ドキュメントには書かれていないので、実機で確かめる | 本文に記述なし（iPhone の振る舞いからの読み取り） | openSettingsURLString |
| ヘルスケアの呼び方 | 画面の文では「Apple Health」または「Apple Health app」と呼ぶ。「HealthKit」と書かない。端末に表示される訳語を使う | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/healthkit |

## アカウントへの当てはめ

- **ヘルスケア**: 許可の状態は出さない。読み取る種類と書き込む種類を並べ、変えるときの行き方（iPhone の設定 > プライバシー > ヘルスケア、またはヘルスケアアプリ）を文で示す。切り替えのスイッチは置かない
- **通知**: 許可の状態を出し、変えるときは iPhone の設定にあるこのアプリの通知のページを開く
- **カメラ**: 許可の状態を出し、変えるときは iPhone の設定にあるこのアプリのページを開く
