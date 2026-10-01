# 手で確かめる項目（Xcode の画面と実機が要るもの）

`run-on-mac.sh` を回したあと、`xcodegen generate` で作った `PreviewLab.xcodeproj` を Xcode 27 で開いて確かめる。実機の項目は、Xcode の Signing でチームを選ぶか、`DEVELOPMENT_TEAM=<チームの ID> xcodegen generate` で作り直す。結果は `out/manual.md` に、項目の番号と「できた・できなかった・その様子」を1行ずつ書く。

1. `Views.swift` の `#Preview("arguments", arguments: SyncSample.allCases)` が、キャンバスに4つの格子で並ぶか。1つを押すと Interactive で開くか
2. キャンバスの Variants（左下）で、Color Scheme と Dynamic Type が横に並ぶか。`arguments` のプレビューと組み合わせられるか
3. `#Preview("modifier", traits: .redTint)` が赤で描かれるか（灰色なら PreviewModifier が当たっていない）
4. `HealthProbe.swift` の `#Preview("health")` で「Request authorization」を押すと、何が出るか（許可のシート・エラーの文・何も起きない）
5. ケーブルでつないだ iPhone を、キャンバスの機器の選択で選べるか。選ぶと実機にプレビューが出て、コードを変えるとすぐ実機に出るか
6. Wi-Fi でペアリングした iPhone（ケーブルを抜いた状態）で、5 と同じことができるか
7. 実機で、4 のヘルスケアの許可がどうなるか
8. Mac のエージェント（Claude Code と MobileBuildMCP）に「`experiments/preview-lab/Sources/Views.swift` の arguments のプレビューを RenderPreview で描いて」と頼み、4つの状態が画像で返るか。Variants（ダーク・大きい文字）を指定して描けるか
