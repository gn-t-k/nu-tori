# 端末とサーバーの両方に置く決めごと

端末とサーバーの両方に置く決めごとは、係数や範囲をデータ（JSON）にしてルートの `shared/` に置き、両側で読む。

- サーバーは import で読み、端末は JSON から書き出した Swift のファイル（`ios/NuToriCore/Sources/NuToriCore/Generated/`）で持つ。書き出しは `ios/SharedRulesGenerator/` のパッケージで動かし、JSON を変えたら `scripts/check ios --fix` で書き出し直す（`scripts/check ios` が最新かを確かめる）。書き出す JSON を足すときは、生成器にも足す
- 手順は両側に書き、入力と期待値の JSON も `shared/` に置いて両方のテストで読む
- 値や検証の結果が違ったときは、サーバーを正とする
- 小さな純粋な計算の域を超えたら、TypeScript で1回だけ書き、端末では JavaScriptCore で動かす
