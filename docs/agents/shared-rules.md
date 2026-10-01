# 端末とサーバーの両方に置く決めごと

端末とサーバーの両方に置く決めごとは、係数や範囲をデータ（JSON）にしてルートの `shared/` に置き、両側で読む。

- サーバーは import で読み、端末は JSON から書き出した Swift のファイル（`ios/NuToriCore/Sources/NuToriCore/Generated/`）で持つ。書き出しは `ios/SharedRulesGenerator/` のパッケージで動かし、JSON を変えたら `scripts/check ios --fix` で書き出し直す（`scripts/check ios` が最新かを確かめる）。書き出す JSON を足すときは、生成器にも足す
- 手順は両側に書き、入力と期待値の JSON も `shared/` に置いて両方のテストで読む
- 値や検証の結果が違ったときは、サーバーを正とする
- 小さな純粋な計算の域を超えたら、TypeScript で1回だけ書き、端末では JavaScriptCore で動かす

## 日の区切り

日の区切りは、時刻と、その時刻の UTC との時差から日を出す1本にそろえる。日は、時刻に時差を足した UTC の日付。

- サーバーは `computeCalendarDay(時刻, 時差の秒)`（`server/src/domain/compute-calendar-day/`）、端末は `CalendarDay(containing:utcOffsetSeconds:)`（NuToriCore）。入力と期待値は `shared/calendar-day.test-cases.json` で、時差は秒の整数で持つ。+05:30 や +05:45 のような分の端数の時差の場面を含む
- 時差でなく IANA 名で持つ値（体重記録の日、使い始めた日、利用状況を数える日）は、IANA 名からその時刻の時差を出して渡す。サーバーは `computeCalendarDayInTimeZone`（中で `computeUtcOffsetSeconds` を呼ぶ）、端末は `CalendarDay(containing:in:)`（中で `TimeZone.secondsFromGMT(for:)` を呼ぶ）。夏時間の切り替わりの前後の場面を含む入力と期待値は `shared/calendar-day-in-time-zone.test-cases.json` で、時差も期待値に持つ
- 写真の食事のように IANA 名が分からず時差だけを持つ値は、その時差をそのまま渡す
- いまの端末のタイムゾーンで決めるのは、どの日が今日で、どの週が今週かだけ

## 今は片側だけの決めごと

両側に置く決めごとのうち、今は端末だけ（またはサーバーだけ）に置いているもの。両側に置く仕様が来たとき、手順と入力と期待値を `shared/` に移し、この一覧から消す。決めごとを書き直すときは、この一覧に抜けが無いかも見る。

| 決めごと | 今の置き場 | 両側にする仕様 |
|---|---|---|
| 栄養の合計（材料の栄養 = 値 × 量 × 1単位あたりの可食部の g ÷ 基準の g。「不明」の材料が混じれば「以上」、すべて「不明」なら「不明」。kcal は材料の kcal の和。ADR-0016） | 端末（NuToriCore の `NutrientTotals`。サーバーは合計を使わない） | サーバーで合計を使う最初の仕様（「文章と会話」の見込み。AI の発言に渡す文脈に、今日の食事の栄養と直前 7 日の日ごとの合計が入るため） |
| 日の代表値（その日の体重記録から1つの値を選ぶ決まり） | 端末（NuToriCore の `RepresentativeWeight`） | 「体重の傾向と記録忘れの通知」（#103 の本文） |
