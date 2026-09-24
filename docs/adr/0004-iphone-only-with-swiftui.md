# 初回リリースは iPhone だけを SwiftUI で作る

初回リリースは iPhone だけを対象にし、Swift（SwiftUI）のネイティブアプリとして作る。開発者は Web（React、TypeScript）が専門だが、React Native は選ばない。標準の部品を使えば新しい iOS の見た目にビルドし直すだけで追従でき、ヘルスケアとカメラを Apple の API で直接使えるため。Android 版を出すときは Android に合わせて UI を作り直す方針なので、React Native の利点であるコードの共有は API クライアントなどに限られる。

## 起きること

- iOS のビルドと画面の確認には Mac が要る。Linux のクラウドのエージェントでは画面以外を進め、macOS の CI で確かめる
- 審査を通さずに直す手段（OTA 更新）がない。TestFlight で身近な人に先に使ってもらって補う
- ヘルスケアのバックグラウンドの取り込みは実機でしか確かめられないので、人が確かめる

根拠: `docs/ui-design/0001-first-release/06-layout.md` の「フォームファクタと作り方」、`docs/research/swift-vs-react-native.md`、`docs/research/agent-ios-verification.md`
