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

## 日の代表値

その日の体重記録から1つの値を選ぶ決まり。体重の傾向の計算と、端末の点（タイムラインと傾向のグラフ）に使う。

- サーバーは `computeDailyRepresentativeWeights`（`server/src/weight-record/domain/compute-daily-representative-weights/`）が正本、端末は NuToriCore の `RepresentativeWeight`。入力（体重記録の ID・時刻・タイムゾーン・値の並び）と期待値（日ごとの代表値）は `shared/daily-representative-weight.test-cases.json`
- 同じ時刻の記録が2つある日、西へ移って同じ日付の記録が時刻の順と入れ替わる日、日付が変わる直前と直後の場面を含む

## 受け付ける値の範囲

- 範囲は `shared/accepted-ranges.json`、入力と期待値は `shared/accepted-ranges.test-cases.json`。サーバーは `isWithinAcceptedRange`（`server/src/domain/is-within-accepted-range/`）、端末は書き出した `AcceptedRange` の `bounds.contains`
- 範囲ごとに、下限は `minimum`（含む）か `exclusiveMinimum`（含まない）、上限は `maximum`（含む）で書く。書いていない側は限りが無い（料理と材料の量は「0 より大きい」なので `exclusiveMinimum` だけ）
- 身長（`heightCentimeters`）と年齢（`ageYears`）は、初めて目標を立てるときの身体データの範囲。打ち間違い（m で入れた身長など）を止めるだけの広い幅にする（体重と同じ考え）。サーバーは、推定消費カロリーを式で出すとき（`computeInitialExpenditureEstimate`。`server/src/expenditure-estimate/domain/`）に当てる。年齢は、生年月日か生まれた年から端末が出した歳
- 料理の名前は、前後の空白を除いた文字数を `dishNameTrimmedLength` に当てる。前後の空白を除くのは、サーバーは `String.prototype.trim`、端末は `trimmingCharacters(in: .whitespacesAndNewlines)`
- 送った文章の本文は、料理の名前と同じ手順で前後の空白を除き、Unicode のコードポイントの数を `sentTextBodyTrimmedLength` に当てる。サーバーは `Array.from(text).length`、端末は `unicodeScalars.count`。端末とサーバーで同じ数になるようにコードポイントで数える（絵文字や結合文字は、見た目の1字が2つ以上に数えられることがある）

## 受け付ける期限

目標の期限は、開始の日から両端を含めて数えた日数が、下限から上限まで（4〜26 週）の日だけを受け付ける。

- 日数は `shared/accepted-deadline-days.json`、入力（開始の日・期限の日）と期待値（受け付けるか）は `shared/accepted-deadline-days.test-cases.json`。サーバーは `src/goal/domain/accepted-deadline/`（受け付ける期限の日数を数える `countAcceptedDaysToDeadline`、開始の日がずれたとき期限を幅に寄せる `moveDeadlineIntoAcceptedRange`）、端末は書き出した `AcceptedDeadlineDays` を使う `GoalDeadlineChoices` の `contains`
- 年をまたぐ場面と、うるう年の2月をまたぐ場面を含む

## 栄養の合計

料理・食事・日の栄養の合計の出し方。材料の栄養は、値 × 量 × 1単位あたりの可食部の g ÷ 基準の g（成分表と AI の推定は可食部 100 g、栄養成分表示は表示の単位の可食部の g）。合計は値の分かる材料の分だけを足し、「不明」の材料が混じれば「以上」、すべて「不明」なら「不明」にする。kcal は材料の kcal の和で、P・F・C から出し直さない（ADR-0016）。

- サーバーは `computeNutrientTotal`（`server/src/ingredient/domain/compute-nutrient-total/`。栄養の項目ごとに出す）、端末は NuToriCore の `NutrientTotals`。入力（材料の量・1単位あたりの可食部の g・出どころ・栄養の値）と期待値（項目ごとの合計）は `shared/nutrient-totals.test-cases.json`
- 料理の合計から食事と日の合計を足し上げる手順（端末の `NutrientTotals(combining:)`、推定を待つ料理を「以上」にすること）は端末の見た目のためのもので、両側の決めごとに含めない。サーバーは食事と日の合計を材料から直に出す

## その日の1日の目安

ある日に食べた量を、どの1日の目安と比べるかの引き方。端末は1日の丸と日のまとめ（電波が無くても見せるため、キャッシュの目標と1日の目安の記録で引く）、サーバーは AI に渡す文脈に使う。日は YYYY-MM-DD の文字列の順で比べる。

1. その日 d を含む目標を選ぶ: 開始の日 ≦ d で、閉じていないか、終わった日（次の目標の開始の日）> d の目標。2つ以上あれば、開始の日、決めた時刻の順で遅いほう
2. その目標の1日の目安のうち、当てる始まりの日 ≦ d で最も遅いもの
3. 目標が無ければ、その日は比べない。目標があって1日の目安が無い（まだ届いていない）ときも比べない

- サーバーは `findDailyGuideForDay`（`server/src/daily-guide/domain/find-daily-guide-for-day/`。その日を含む目標と、その1日の目安を返す）、端末は NuToriCore の `DailyGuideForDay`（同じ組を返す。タイムラインの日と1日の丸が持つ `dailyGuide` はここから引く）。入力（日、目標の ID・開始の日・決めた時刻・閉じていれば終わった日の並び、1日の目安の ID・目標の ID・当てる始まりの日の並び）と期待値（目標の ID と1日の目安の ID。無ければ `null`）は `shared/daily-guide-for-day.test-cases.json`
- 同じ日に2回立て直した日（間の目標は開始の日と終わった日が同じで、どの日も含まない）、目標を立てる前の日、閉じていない目標が2つあるとき（閉じた目標の変更がまだ届いていない端末で起きる）、見送った週の日（その週に当てる1日の目安が無く、前の週のものが当たる）、親の目標がまだ届いていない1日の目安の場面を含む
- 2つ目以降の目標の1日の目安は、当てる始まりの日が d 以前でいくら遅くても選ばない（1 で選んだ目標のものだけを見る）

## ペース

今の体重の傾向の動きのままで期限に目標体重へ届くか（維持では、体重の傾向が目標体重の近くに収まっているか）の出し方。端末は1日の丸・日のまとめ・体重の画面・週の振り返り（電波が無くても見せるため、同期で届いた体重の傾向から出す）、サーバーは AI に渡す文脈に使う。日は YYYY-MM-DD の文字列の順で比べ、日数は `countDaysBetween`（同じ日は 0）で数える。

- 判定する日: 週の振り返りではその週の日曜、ほかは今日
- ある日の体重の傾向は、その日以前で最も新しい日の値を使う（体重の傾向は最後の体重記録の日で終わる）

減量・増量は、上から順に当てて最初に当たったものを返す。

1. 返さない: 判定する日が期限の日以降か、達成した日以降
2. まだ出ない: 開始の日から判定する日までの日数が 14 未満（14 日前の体重の傾向が目標の中に入るまで）
3. 言い切らない: 判定する日とその前の 13 日（14 日）に体重記録のある日が4日未満。記録のある日数を添える
4. 間に合う・届かない:
   - 実際の速さ（kg/週）=（判定する日の体重の傾向 − その 14 日前の体重の傾向）÷ 2
   - 見込み = 判定する日の体重の傾向 + 実際の速さ × 判定する日から期限の日までの日数 ÷ 7
   - 見込みが目標体重と同じか、それより向きの側（減量は軽い側、増量は重い側）なら間に合う。浮動小数の誤差で、ちょうど目標体重の見込みを届かないことにしない
   - 届かなければ、見込みと目標体重との差を届かない kg として返す。0.1 kg 単位に切り上げる（0.1 kg に満たない不足を「0.0 kg」にしない）
   - どちらにも、実際の速さと要るペース（=（目標体重 − 判定する日の体重の傾向）÷ 判定する日から期限の日までの日数 × 7）を、0.1 kg 単位に四捨五入して添える。要るペースは週の振り返りの文だけが使い、1日の目安の必要な速さは使わない

維持（期限後の維持を含む）は、判定する日の体重の傾向が目標体重の ±0.7 kg（端を含む）に収まっているかだけを返す。

- サーバーは `computePace`（`server/src/goal/domain/compute-pace/`）。入力（判定する日、体重の傾向の日ごとの並び、体重記録のある日、目標の向き・開始の日・期限の日・目標体重、達成した日）と期待値（`status` が `onTrack`・`behind`・`inconclusive`・`pending`・`unavailable`・`maintenance` と、それぞれに添える値）は `shared/pace.test-cases.json`。維持の目標は期限の日を `null` で持つ
- 期限の日とその前の日、達成した日とその前の日、開始の日から 13 日と 14 日、記録のある日 3 と 4 日（14 日より前の日を数えないこと）、見込みがちょうど目標体重、維持の幅のちょうど端、最後の体重記録が判定する日より前の場面を含む

## 今は片側だけの決めごと

両側に置く決めごとのうち、今は端末だけ（またはサーバーだけ）に置いているもの。両側に置く仕様が来たとき、手順と入力と期待値を `shared/` に移し、この一覧から消す。決めごとを書き直すときは、この一覧に抜けが無いかも見る。

今は無い。
