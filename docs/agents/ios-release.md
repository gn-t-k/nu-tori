# iOS のアプリの配布と実機の確認

## 配布

- Xcode Cloud のワークフローは「main から内部テスト」の1つ。枠（月 25 時間）に収めるため、main の `ios/` が変わったとき（と手で始めたとき）だけ動かし、アクションは Archive（Distribution Preparation は App Store Connect。外部テストと App Store に出せるのはこれだけ）だけにする。配る先は内部テストのグループ「初回リリーステストユーザーグループ」。設定は Xcode の Report navigator の Cloud のタブで直す
- Xcode Cloud の秘密の値は、ワークフローの Environment に Secret で置く。アーカイブのあとに `ios/ci_scripts/ci_post_xcodebuild.sh` が dSYM を Sentry に上げ、`SENTRY_AUTH_TOKEN`（Sentry の組織のトークン）が無ければ飛ばす

## 実機の確認

エージェントには実機を操作する道が無いので、人が確かめる。

- 確かめるのは、ヘルスケア、カメラ、通知、写真の読み込みに触れた PR をマージしたあとと、外部テストに出す前。確かめる項目は、実機のチケット（`docs/agents/issue-tracker.md` の「iOS のチケットの分け方」）に、どこを押して何が見えれば合格かの形で並べる。チケットの無い PR では、PR の本文に「実機の確認が要る」と書いて並べる
- ヘルスケアは、「[ヘルスケアの読み書きの対応表](https://github.com/gn-t-k/nu-tori/issues/27)」の追記の「実機で確かめるまで見込みのもの」に加えて、他のアプリの当日の体重で通知が取り消されることを確かめる。nu-tori を閉じてヘルスケアアプリで体重を手入力すると、その日の体重の通知が取り消され、開くと体重のボタンが目立たない。MacroFactor で入れても同じになる
- 栄養は、ヘルスケアアプリに nu-tori の食品の組として入っていれば合格にする。MacroFactor・FoodNoms が取り込むかは確かめない。どちらも取り込み方がアプリ側の決まりに左右される（MacroFactor は日の合計を Nutrition のページにだけ出し、その日に MacroFactor で記録があると取り込まない。`docs/research/healthkit-foodnoms-macrofactor.md`）
