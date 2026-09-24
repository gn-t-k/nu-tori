# P・F・C にどの色を当て、iOS のシステムカラーはどれだけ読めるか

調査日: 2026-09-24
対象: P・F・C（たんぱく質・脂質・炭水化物）の色分け。ほかの食事記録アプリ（MacroFactor、Foodnoms、Cronometer、MyFitnessPal、あすけん、カロミル、Apple のヘルスケア）がどう色を当てているかと、iOS のシステムカラーのコントラスト比、Apple Human Interface Guidelines（以下 HIG）が色とコントラストについて求めていること

> **確認の方法と限界**
> - HIG の Color・Accessibility・Dark Mode・Charts・Charting data の各ページは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（例: `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/color.json`）を取得して**本文を直接読んだ**。システムカラーの値は、Color ページの Specifications の表にある色見本画像の代替テキスト（例: `R-0,G-136,B-255`）から取った。出典にはふつうの URL を書く。
> - アプリの色は、公式ヘルプセンター（Zendesk の記事は公開 API で本文と添付画像を取得）と、App Store の公式スクリーンショット（iTunes Lookup API で取得した画像）で確かめた。文章で色が書いてあるものは「本文で確認」、画像から色を読んだものは「本文からの読み取り」とし、どの画像かを添える。画像から取った16進数は、画面写真の画素をそのまま読んだおおよその値で、アプリが公式に示した値ではない。
> - 公式に16進数の値を示したアプリは見つからなかった。Apple のヘルスケアが P・F・C に色を分けているかは、Apple の公開ページでは確認できなかった。
> - コントラスト比は WCAG 2 の式で自分で計算した（式は下に書く）。HIG は値の色空間を書いていないため、sRGB の値として計算した。HIG 自身が「値はリリースごとに変わりうる」と書いているため、実機の値とは違うことがある。
> - 実機での確認はしていない。二次情報（ブログ、記事、SNS）は使っていない。Cronometer の公式フォーラムに 2017 年のユーザーの報告（当時の iOS 版で画面により色が違った）があるが、ユーザーの投稿で古いため根拠にしていない。

## 結論の要約

- P・F・C の色に業界共通の決まりはない。P・F・C それぞれに別の色を当てていると確かめられたのは4アプリ（MacroFactor、Foodnoms、Cronometer、MyFitnessPal）で、4つとも組み合わせが違う（本文で確認・本文からの読み取り）
- いちばん多いのは**たんぱく質＝オレンジ**（4アプリ中3つ: MacroFactor、Foodnoms、MyFitnessPal）。炭水化物は**青〜青緑**（Foodnoms 青、Cronometer 水色、MyFitnessPal 青緑）が3つ。脂質はばらばらで、**紫**が2つ（Cronometer、MyFitnessPal）、黄と緑が1つずつ（本文からの読み取り）
- 国内の2アプリは P・F・C に固定の色を当てていない。カロミルは P・F・C を同じ緑で示し、目標を超えると黄〜オレンジに変える。あすけんは栄養素グラフをすべて同じ緑で示し、PFC バランスの画面の色が栄養素ごとの色か、不足・過剰・適正の状態の色かは確認できず（本文からの読み取り）
- iOS のシステムカラーの既定（ライト）は、白の上で 4.5:1 に届くのは Indigo（5.09）だけ。Green・Orange・Teal・Yellow は 3:1 にも届かない。「コントラストを上げる」のライト版は9色すべて白の上で 4.5:1 をわずかに超える（4.54〜6.12）が、#F2F2F7 の上では Indigo と Purple 以外は 4.5:1 を下回る（計算）
- HIG は、色だけで情報を伝えない（形・ラベル・パターンを添える）、システムカラーを使う、ライト・ダーク・コントラストを上げるの全部で確かめる、文字は WCAG AA（17pt 以下は 4.5:1、18pt 以上か太字は 3:1）を目安にする、と求める。グラフでは、隣り合う色の間に区切りを入れることも勧める（本文で確認）

## 根拠

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| MacroFactor の P・F・C の色 | P＝オレンジ、F＝黄、C＝緑。「たんぱく質・脂質・炭水化物は、それぞれオレンジ・黄・緑で色分けされる」（"you can see your protein, fat, and carbohydrate intake color-coded in orange, yellow, and green, respectively"）。P・F・C で説明できないカロリーは青の「Other」 | 本文で確認 | https://help.macrofactorapp.com/en/articles/226-what-are-the-blue-other-calories-on-my-nutrition-page |
| MacroFactor の色の値 | 公式の16進数は見つからない。App Store の6枚目（CHECK IN WEEKLY、ダーク）の「112 P」の札がおよそ #FE875F（サーモン寄りのオレンジ）、5枚目（TRACK MICROS）の脂質の内訳のバーがおよそ #FCF066（黄）。炭水化物の緑はスクリーンショットに見当たらない | 本文からの読み取り（画像の画素） | https://apps.apple.com/us/app/macrofactor-macro-tracker/id1553503471 |
| Foodnoms の P・F・C の色 | P＝オレンジ、F＝緑、C＝青。3枚目（See Your Progress at a Glance）の Macros のカードで、C・F・P の丸い印と積み上げ棒がこの色。1枚目の Goals の輪と、9枚目のウィジェットも同じ組み合わせ。カロリーは赤。画素はおよそ C #0099F7、F #02B33F、P #FF6D00 | 本文からの読み取り（画像） | https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686 |
| Cronometer の P・F・C の色 | P＝緑、F＝紫、C（Net Carbs）＝水色、エネルギー＝オレンジ、アルコール＝黄。ヘルプ記事「Mobile - Macronutrient Breakdown」の1枚目の画面写真のバーの画素はおよそ Energy #EF8560、Protein #84D395、Net Carbs #70CDDA、Fat #B37CC8。App Store の1・2・6枚目（Report の Protein・Carbs・Fat・Alcohol の凡例）も同じ組み合わせ | 本文からの読み取り（画像） | https://support.cronometer.com/hc/en-us/articles/32659895319444-Mobile-Macronutrient-Breakdown 、https://apps.apple.com/us/app/cronometer-calorie-counter/id1145935738 |
| MyFitnessPal の P・F・C の色 | P＝オレンジ（山吹）、F＝紫、C＝青緑。App Store の3枚目（Make Every Meal Count）の凡例の四角の画素はおよそ Carbohydrates #2CB9B1、Fat #6C0D8D、Protein #FEB13D。ヘルプ記事「Macros By Meal」の2枚目の画面写真（Breakfast の輪）と、App Store の7・10枚目の Carbs・Fat・Protein のバーも同じ組み合わせ。ヘルプの文章に色の記述はない | 本文からの読み取り（画像） | https://apps.apple.com/us/app/myfitnesspal-calorie-counter/id341232718 、https://support.myfitnesspal.com/hc/en-us/articles/360032625151 |
| あすけんの P・F・C の色 | 固定の色は確認できず。アドバイスの「摂取栄養素グラフ」は、ヘルプの画面写真ではエネルギー・たんぱく質・脂質・炭水化物・ビタミンがすべて同じ緑のバー（App Store の5枚目では、バーが緑・青・オレンジ・黄に分かれており、栄養素ではなく別の区分の色に見える）。App Store の8枚目（PFCバランスがすぐわかる）では P＝オレンジ、F＝赤みのオレンジ、C＝黄緑だが、それぞれ「あと 50g」「過剰 25g」「適正」のラベルと並んでおり、栄養素の色か状態の色かは画像だけでは決められない | 本文からの読み取り（画像）、確認できず（固定の色があるか） | https://apps.apple.com/jp/app/id687287242 、https://asken.jp/lp/app/information/plan202308/ |
| カロミルの P・F・C の色 | P・F・C に別々の色は当てていない。栄養サマリーのバーと PFC の数字はすべて同じ緑で、ヘルプの「PFCバランスについて」の三角形の図も緑1色。App Store の5枚目では、目標を超えた炭水化物・糖質のバーの先が黄〜オレンジになる。ヘルプの文章は「目標値の±10%で達成とし、達成した項目は緑でマークされます」 | 本文で確認（達成を緑で示すこと）、本文からの読み取り（栄養素ごとの色がないこと） | https://support.calomeal.com/hc/ja/articles/16141442142105 、https://support.calomeal.com/hc/ja/articles/900005588806 、https://apps.apple.com/jp/app/id963055562 |
| Apple のヘルスケアの P・F・C の色 | 確認できず。iPhone ユーザガイドの「ヘルスケアでデータを表示する」などに、栄養素ごとの色の記述は見当たらない | 確認できず | https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios |
| 共通の決まりはあるか | ない。4アプリの組み合わせはすべて違う。たんぱく質＝オレンジが3つ、炭水化物＝青〜青緑が3つ、脂質＝紫が2つで、残りは黄・緑。国内の2アプリは栄養素ごとに色を分けず、ブランドの緑と状態の色（達成・過剰など）を使う | 本文からの読み取り（上の行から） | 上の各行 |
| iOS のシステムカラーの値 | Color ページの Specifications の表が、12色それぞれについて既定（ライト・ダーク）と Increased contrast（ライト・ダーク）の4つの RGB を示す。値は下の表 | 本文で確認（色見本の代替テキスト） | https://developer.apple.com/design/human-interface-guidelines/color |
| 値をそのまま使ってよいか | 使わない。「システムカラーの値をアプリに直書きしない。値は設計の参考。実際の値はリリースごとに変わりうる」（"Avoid hard-coding system color values in your app. Documented color values are for your reference during the app design process. The actual color values may fluctuate from release to release"）。2025年6月9日に値が更新されている（"Updated system color values"） | 本文で確認 | 同上 |
| 最低限のコントラスト比 | Accessibility Inspector は WCAG レベル AA の値を目安にする。17pt まで: 4.5:1、18pt: 3:1、太字: 3:1（"Up to 17 pts ｜ All ｜ 4.5:1" "18 pts ｜ All ｜ 3:1" "All ｜ Bold ｜ 3:1"）。「コントラストの最低基準を満たすよう努める」（"Strive to meet color contrast minimum standards."）。WCAG と APCA の両方を挙げている | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| 既定の色で基準に届かないとき | 「既定で最低のコントラストを満たさないなら、少なくとも『コントラストを上げる』がオンのときにより高いコントラストの配色を用意する」（"If your app doesn’t provide this minimum contrast by default, ensure it at least provides a higher contrast color scheme when the system setting Increase Contrast is turned on."）。ダークモードに対応するなら両方の見た目で確かめる | 本文で確認 | 同上 |
| ダークモードでの比 | 「最低でも 4.5:1 を下回らない。独自の前景色と背景色では、特に小さな文字で 7:1 を目指す」（"At a minimum, make sure the contrast ratio between colors is no lower than 4.5:1. For custom foreground and background colors, strive for a contrast ratio of 7:1, especially in small text."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/dark-mode |
| 色だけに頼ってよいか | 頼らない。「色だけで情報を伝えない」（"Convey information with more than color alone."）。赤と緑、青とオレンジの組み合わせは色覚の違いで見分けにくいことがあり、形やアイコンを添える。グラフの色を利用者が変えられるようにすることも考える（"Consider allowing people to customize color schemes such as chart colors"）。Color ページも「色だけで物を区別したり大事な情報を伝えたりしない」「文字のラベルや形で示す」（"Avoid relying solely on color to differentiate between objects, indicate interactivity, or communicate essential information." "you can use text labels or glyph shapes"） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/accessibility 、https://developer.apple.com/design/human-interface-guidelines/color |
| システムカラーを使うべきか | 使える所では使う。「システム定義の色を優先する。コントラストを上げる、ライトとダークの切り替えに自動で合わせる」（"Prefer system-defined colors. These colors have their own accessible variants that automatically adapt when people adjust their color preferences, such as enabling Increase Contrast or toggling between the light and dark appearances."）。独自の色では、ライトとダークの版と、それぞれに「コントラストを上げる」版を用意する（"If you define a custom color, make sure to supply light and dark variants, and an increased contrast option for each variant"） | 本文で確認 | 同上 |
| 同じ色を別の意味に使ってよいか | 使わない。「同じ色で別のことを表さない」（"Avoid using the same color to mean different things."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/color |
| グラフの色 | 「グラフで、データの区別や大事な情報を色だけに頼らない」「形やパターンを変えて補う」（"Avoid relying solely on color to differentiate between different pieces of data or communicate essential information in a chart." "use different shapes or patterns to depict different parts of data"）。積み上げ棒のように色が隣り合うところには区切りを入れる（"Aid comprehension by adding visual separation between contiguous areas of color."）。アクセシビリティのラベルでは色ではなく何を表すかを書く（"Describe what the chart’s details represent, not what they look like."） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/charts |
| 複数のグラフで色をそろえるか | そろえる。同じデータを別の見方で示すときは、グラフの種類・色・注記・レイアウトをそろえる（"use one chart type and consistent colors, annotations, layouts, and descriptive text"） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/charting-data |
| システムカラーのコントラスト比 | 下の表のとおり。既定（ライト）は Indigo 以外、白の上で 4.5:1 に届かない。「コントラストを上げる」（ライト）は9色とも白の上で 4.5:1 を超えるが、#F2F2F7 の上では 4.07〜5.49 で、Indigo・Purple 以外は 4.5:1 を下回る。ダークの版（既定・コントラストを上げるとも）は黒の上で 5.79〜15.85 あり、すべて 4.5:1 を超える | 計算（値は本文で確認） | https://developer.apple.com/design/human-interface-guidelines/color |

## コントラスト比の計算

WCAG 2 の式を使った。

- 各チャンネル C（0〜255）を c = C / 255 にし、c ≤ 0.04045 なら c / 12.92、それ以外は ((c + 0.055) / 1.055)^2.4 で線形化する
- 相対輝度 L = 0.2126 R + 0.7152 G + 0.0722 B
- コントラスト比 = (L明るい方 + 0.05) / (L暗い方 + 0.05)

背景は白 #FFFFFF、黒 #000000、#F2F2F7（systemGroupedBackground のライト。この値は依頼で与えられたもので、HIG の Color ページには載っていない。同じ RGB 242,242,247 が systemGray6 の既定（ライト）として載っている）。4.5:1 以上を **太字** にした。

| 色 | 版 | 値 | 白 | #F2F2F7 | 黒 |
|---|---|---|---|---|---|
| Blue | 既定・ライト | #0088FF | 3.52 | 3.15 | **5.97** |
| Blue | 既定・ダーク | #0091FF | 3.23 | 2.90 | **6.49** |
| Blue | コントラストを上げる・ライト | #1E6EF4 | **4.57** | 4.10 | **4.59** |
| Blue | コントラストを上げる・ダーク | #5CB8FF | 2.15 | 1.93 | **9.76** |
| Green | 既定・ライト | #34C759 | 2.22 | 1.99 | **9.46** |
| Green | 既定・ダーク | #30D158 | 2.02 | 1.81 | **10.39** |
| Green | コントラストを上げる・ライト | #008932 | **4.54** | 4.07 | **4.62** |
| Green | コントラストを上げる・ダーク | #4AD968 | 1.84 | 1.65 | **11.42** |
| Orange | 既定・ライト | #FF8D28 | 2.31 | 2.07 | **9.09** |
| Orange | 既定・ダーク | #FF9230 | 2.23 | 2.00 | **9.41** |
| Orange | コントラストを上げる・ライト | #C55300 | **4.55** | 4.08 | **4.61** |
| Orange | コントラストを上げる・ダーク | #FFA056 | 2.02 | 1.81 | **10.41** |
| Red | 既定・ライト | #FF383C | 3.57 | 3.20 | **5.88** |
| Red | 既定・ダーク | #FF4245 | 3.43 | 3.08 | **6.12** |
| Red | コントラストを上げる・ライト | #E9152D | **4.56** | 4.08 | **4.61** |
| Red | コントラストを上げる・ダーク | #FF6165 | 2.94 | 2.63 | **7.15** |
| Indigo | 既定・ライト | #6155F5 | **5.09** | **4.56** | 4.13 |
| Indigo | 既定・ダーク | #6D7CFF | 3.51 | 3.15 | **5.98** |
| Indigo | コントラストを上げる・ライト | #564ADE | **6.12** | **5.49** | 3.43 |
| Indigo | コントラストを上げる・ダーク | #A7AAFF | 2.13 | 1.91 | **9.84** |
| Purple | 既定・ライト | #CB30E0 | 4.17 | 3.74 | **5.04** |
| Purple | 既定・ダーク | #DB34F2 | 3.63 | 3.25 | **5.79** |
| Purple | コントラストを上げる・ライト | #B02FC2 | **5.21** | **4.67** | 4.03 |
| Purple | コントラストを上げる・ダーク | #EA8DFF | 2.15 | 1.93 | **9.75** |
| Teal | 既定・ライト | #00C3D0 | 2.16 | 1.94 | **9.72** |
| Teal | 既定・ダーク | #00D2E0 | 1.86 | 1.67 | **11.30** |
| Teal | コントラストを上げる・ライト | #008198 | **4.57** | 4.10 | **4.59** |
| Teal | コントラストを上げる・ダーク | #3BDDEC | 1.65 | 1.48 | **12.74** |
| Pink | 既定・ライト | #FF2D55 | 3.65 | 3.27 | **5.76** |
| Pink | 既定・ダーク | #FF375F | 3.52 | 3.16 | **5.96** |
| Pink | コントラストを上げる・ライト | #E7124D | **4.57** | 4.10 | **4.59** |
| Pink | コントラストを上げる・ダーク | #FF8AC4 | 2.17 | 1.94 | **9.68** |
| Yellow | 既定・ライト | #FFCC00 | 1.51 | 1.35 | **13.89** |
| Yellow | 既定・ダーク | #FFD600 | 1.41 | 1.27 | **14.87** |
| Yellow | コントラストを上げる・ライト | #A16A00 | **4.59** | 4.11 | **4.58** |
| Yellow | コントラストを上げる・ダーク | #FEDF43 | 1.32 | 1.19 | **15.85** |

読み方の注意:

- ライトの版は白か #F2F2F7 の上、ダークの版は黒の上に置く前提で見る。ライトの版を黒の上で、ダークの版を白の上で比べた値は参考にとどまる
- 3:1 は、HIG の表では 18pt 以上か太字の文字の基準。文字でないグラフの面や線に HIG は比の数値を示していない
