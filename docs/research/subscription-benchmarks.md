# サブスクの基準値（無料体験から有料への転換、継続率、ダウンロードからの転換、日本の価格、Sean Ellis のテスト、継続の曲線の平らさ）

調査日: 2026-10-23
対象: nu-tori の PMF の判定に使う数の目安。nu-tori は日本の iPhone アプリ（ヘルスケア／フィットネスのカテゴリ）で、食事の写真の記録と体重の傾向から 1 日の目安の kcal を見直す。月額と年額のサブスク（自動更新）を売り、支払いの登録なしの 30 日の無料体験のあとに課金する（App Store の Introductory Offer の無料体験は使わず、サーバーが日数を数える。`docs/research/app-store-subscription.md`）。日本で出すところ。

> **確認の方法と限界**
> - **このセッションからは、どの出典の本文も直接読めなかった。** `curl` は agent proxy が revenuecat.com、adapty.io、developer.apple.com、a16z.com、andrewchen.com、amplitude.com、venturehacks.com、startup-marketing.com などすべてに `CONNECT tunnel failed, response 403` を返し、WebFetch は名前解決に失敗した（`getaddrinfo ENOTFOUND`）。このため、**すべての主張は WebSearch（検索エンジンの結果とその抜粋）から拾った**。検索の対象を一次の出典のドメイン（revenuecat.com、adapty.io、chartmogul.com、developer.apple.com、seanellis.substack.com、venturehacks.com、a16z.com など）に絞って、出典のページの抜粋として返ったものだけを根拠にした。
> - ラベルは次の 4 つ。「**抜粋で確認**」は、一次の出典のページの抜粋として検索結果に出た文と数。原文の前後は読めていないので、指標の定義（分母、期間、中央値か平均か）を取り違えている恐れが残る。「**二次情報の抜粋**」は、一次の出典を引いた解説記事の抜粋で、一次の出典の抜粋では確かめられなかったもの。参考に留める。「**本文からの読み取り**」は、上の数から推し量ったものや nu-tori への当てはめ（掛け算での推計を含む）。「**本文を探したが記述なし**」は、探しても見つからなかったもの。どれも、ページを開いて全文を読んだ「本文で確認」ではない。
> - RevenueCat の State of Subscription Apps は **2026 年版**（115,000 以上のアプリ、160 億ドル以上の収益、iOS・Android・Web）を最新として扱った。2025 年版・2024 年版の数は、年版を書いて分けた。Adapty の State of In-App Subscriptions は 2026 年版（16,000 以上のアプリ、30 億ドル、主に App Store、2025 年のデータ）。
> - **RevenueCat と Adapty の数は、標本も定義も違うので、並べて平均しない。** どちらも自社の課金 SDK を入れたアプリだけの数で、日本の App Store 全体を代表しない。
> - **日本だけ、ヘルスケア／フィットネスだけ、の継続率の 2026 年の数は見つからなかった。** RevenueCat 2026 は日本を韓国・オーストラリア・ニュージーランドと一緒に「Asia-Pacific」にまとめている。
> - 抜粋どうしが食い違う箇所がある（ヘルスケア／フィットネスの売上が年額と月額のどちらに偏るか、など）。食い違いはそのまま書いた。
> - **数を基準に使う前に、開発者がブラウザで RevenueCat 2026 のページ（とヘルスケア／フィットネスの切り出し）を開いて、少なくとも「結論の要約」に出した数を確かめ直すことを勧める。**

## 結論の要約

- **無料体験から有料（trial→paid）**: RevenueCat 2026 では、ヘルスケア／フィットネスの中央値は **37.7%**、上位 4 分の 1 は **51.4% より上**（抜粋で確認 RC1）。Asia-Pacific 全体の中央値は 31.9%、上位 4 分の 1 は 45.6% より上（抜粋で確認 RC1）。Adapty 2026 ではヘルスケア／フィットネスは **35.0%**（全体平均 25.6%）（抜粋で確認 AD1）。**ただしこれらは App Store の無料体験（支払いの登録が要り、解約しなければ自動で有料に移る「opt-out」の形）の数と読むのが自然で、nu-tori の「支払いの登録なし（opt-in）」の 30 日とはそのまま比べられない**（本文からの読み取り）。モバイルのアプリで opt-in と opt-out を比べた一次の数は見つからなかった（本文を探したが記述なし）。SaaS では ChartMogul 2026 が「カード必須の無料体験は 30% で、カード不要の 5 倍を超える」と書く（抜粋で確認 CM1）。
- **無料体験の長さ**: RevenueCat 2026 では、17〜32 日の無料体験の trial→paid の中央値は **42.5%**（上位 4 分の 1 は 59.4% より上）、4 日以下は 25.5%（上位 4 分の 1 は 38.5% より上）（抜粋で確認 RC1, RC2）。一方、SaaS の大きな無作為化の実験（Yoganarasimhan ほか、Management Science 2023）は、7・14・30 日を割り当てて**短い 7 日がいちばん良かった**と報告している（抜粋で確認 YB1）。長い無料体験が転換を上げるか下げるかは、出典によって逆になる。
- **ダウンロードから無料体験・有料**: RevenueCat 2026 のヘルスケア／フィットネスは、ダウンロード→無料体験の中央値 **6.9%**（上位は 23% 超）、**35 日目までのダウンロード→有料の中央値 2.9%（iOS では 3.5%）**（抜粋で確認 RC1）。Asia-Pacific のダウンロード→有料（35 日目）は中央値 2.4%、上位 4 分の 1 は 5.1% より上（抜粋で確認 RC1）。**この「ダウンロード→有料」は opt-in と opt-out の違いを分母の側で吸収するので、nu-tori が外の数と比べるにはいちばん使いやすい**（本文からの読み取り）。
- **継続（更新）**: RevenueCat の 2026 年の基準では、ヘルスケア／フィットネスの**月額の初回の更新率は 25 パーセンタイル 46%・中央値 57%・75 パーセンタイル 68%**、**年額の初回の更新率は 16%・25%・37%**（抜粋で確認 RC3）。月額の 2 回目・3 回目の更新率の中央値は、カテゴリをまたいで 65〜77%、73〜82%（抜粋で確認 RC1）。ここから、**月額で払い始めた人が 3 か月目にも残っている割合はおよそ 30%（下位）・40%（中央）・52%（上位）**と推計できる（本文からの読み取り。掛け算の推計）。1 年後の継続は全体の中央値で年額 28%、月額 8%（2026 年、抜粋で確認 RC1）。日本だけの数は 2024 年版にあり、1 年目の継続は年額 42%、月額 26%、初回の更新率の中央値 62% で、日本は世界で最も高いとされた（抜粋で確認 RC4）。
- **日本の価格**: RevenueCat 2026 は、ヘルスケア／フィットネスの価格が月 9.99 ドル・年 39.94 ドルに集まると書く（抜粋で確認 RC1）。Adapty 2026 は日本の年額の平均が世界で最も高い 54.59 ドルとする（カテゴリ別ではない。抜粋で確認 AD1）。日本の App Store での競合の実際の値段は、このリポジトリの既存の調査にある（あすけん 月 580 円・年 4,400 円、MacroFactor 月 1,540 円・年 9,200 円など。`docs/research/competitor-app-store-listings.md`、`docs/research/asken-macrofactor.md`）。返金率は RevenueCat 2026 で価格帯別の中央値 2.7%（安い）・3.9%（中）・4.5%（高い）（抜粋で確認 RC1）、2025 年版ではヘルスケア／フィットネスが 4.71% で教育に次いで高い（抜粋で確認 RC5）。
- **Sean Ellis のテスト**: 問いは「この製品をもう使えなくなったら、どう感じますか」で、**「とても残念（very disappointed）」と答えた人が 40% を超えれば PMF に達したとみる**。本人は、40% は「少し恣意的」で、約 50（のちの版では約 100）のスタートアップの結果を比べて決めたと書き、**回答は最低 30 件ほど**を求める。聞く相手は、**直近 2 週間ほどの間に使っていて、価値を体験した（activated）人の無作為の標本**（抜粋で確認 SE1, SE2, SE3）。
- **継続の曲線が平らになること**: a16z は、継続の曲線が平らになり始めるのは「多くは 3 か月目のあたり」で、時期よりも**最後に平らになること**が大事、と書く（抜粋で確認 A1）。Sean Ellis は、登録の日から数えた曲線は価値を体験しなかった人が混ざって平らにならないことが多く、**起点を activation（価値を体験した時点）に変えると平らな部分が見えることが多い**と書く（抜粋で確認 SE3）。

## 問い1: 無料体験から有料への転換（ヘルスケア／フィットネス、opt-in と opt-out、30 日の長さ）

### カテゴリの数

- RevenueCat 2026: ヘルスケア／フィットネスの trial→paid の中央値は 37.7%、上位 4 分の 1 は 51.4% より上。「Health & Fitness median: 37.7% (top quartile above 51.4%)」。また「Travel and Health & Fitness lead with the highest median trial-to-paid conversion rates」。【抜粋で確認 RC1】
- RevenueCat 2026 の trial→paid の定義は「無料体験を始めた人のうち、有料のサブスクに移った割合」（the share of free trial starts that convert into a paid subscription）。【抜粋で確認 RC1】
- RevenueCat 2025: ヘルスケア／フィットネスの中央値 39.9%、上位 10% は 68.3%。「While Health & Fitness apps have a median of 39.9%, the top 10% convert at 68.3%」。2026 年より少し高い。【抜粋で確認 RC5】
- RevenueCat 2026 の地域別: Asia-Pacific の trial→paid の中央値は 31.9%、上位 4 分の 1 は 45.6% より上。北米・Asia-Pacific・西欧が上で、インド・東南アジアはその半分以下。【抜粋で確認 RC1】
- Adapty 2026: 「Health & Fitness leads trial-to-paid at 35.0%」、全体の平均は 25.6%。インストール→無料体験の全体の平均は 10.9%。【抜粋で確認 AD1, AD2】Adapty の別の報告（State of Paywalls 2026）は、ヘルスケア／フィットネスの trial の転換が地域により 19.8%（中東・アフリカ）から 33.3%（米国）とする。【抜粋で確認 AD3】
- Adapty 2026 は、ヘルスケア／フィットネスで「86.1% of trials on Day 0」、2 つ目の山が 4〜14 日目（2.6%）と書く。抜粋だけでは、これが「インストールの当日に無料体験が始まる割合」か「転換の時期」か読み切れない。【抜粋で確認 AD2。意味は未確定】

### opt-in（支払いの登録なし）と opt-out（登録あり、自動で有料に移る）

- **モバイルのアプリで、opt-in と opt-out の trial→paid を並べた一次の数は見つからなかった。** RevenueCat・Adapty のサイトに絞って探したが、出てきたのは「ハードペイウォールとフリーミアム」の比べだった。【本文を探したが記述なし（revenuecat.com、adapty.io を検索）】
- RevenueCat と Adapty の trial→paid は、App Store・Google Play の無料体験（購入の手続きをして始め、解約しなければ自動で更新される）を数えたものと読める。両社とも SDK がストアの取引から数を作るためで、nu-tori のようにサーバーが日数を数えて「あとで自分で買う」形は、両社の trial の数に入らない。【本文からの読み取り（RC1 の定義と、ストアの無料体験は自動更新のサブスクの導入のオファーであること `docs/research/app-store-subscription.md` から）】
- RevenueCat のコミュニティでは、ストアの無料体験を使わずに「バックエンドから一定期間の権利を与える」形を、支払いの登録なしの無料期間の作り方として示している（権利を与える API を呼ぶ）。転換率の数は無い。【抜粋で確認 RC6】
- ChartMogul 2026（SaaS、200 製品）: 「Free trials that require a credit card see 30% free-to-paid conversion – more than 5x ones that don't require one」。無料体験を出す製品のうちカード必須は 20%。カードを求めると登録が減り、有料の人数の合計が減ることもある、とも書く。カード必須の目安は good 25〜35%、great 50〜60%。【抜粋で確認 CM1】
- SaaS の解説記事には「opt-out 48.8%、opt-in 18.2%」（First Page Sage の数とされる）の数が出回り、Adapty の数として引く記事もある。一次の出典では確かめられなかった。【二次情報の抜粋 X1】
- **nu-tori への当てはめ**: opt-in では、無料体験を始める人（分母）が増え、そのぶん trial→paid の率は opt-out よりずっと低く出る。SaaS の比（5 倍前後）をそのまま当てると、ヘルスケア／フィットネスの 37.7% は opt-in ではおよそ 7〜10% に当たる。ただしモバイルの数での裏付けは無く、桁の目安に留まる。【本文からの読み取り（RC1 と CM1 から）】

### 無料体験の長さ（30 日）

- RevenueCat 2026: 「17–32 day trials median: 42.5% (top quartile above 59.4%). ≤4 day trials median: 25.5% (top quartile above 38.5%)」。RevenueCat のブログ（17,000 以上のアプリ）は同じ 42.5% を「trials of 17+ days」と書き、傾向はプラン・カテゴリ・地域で違い、すべての指標で勝つ長さは無いとする。【抜粋で確認 RC1, RC2】
- RevenueCat 2025: 長い無料体験 45.7%、短い 26.8%。【抜粋で確認 RC5】
- 同じブログは、無料体験を始めた数の上位 100 アプリでは、どのカテゴリでも 4 日以下が多く、ヘルスケア／フィットネスで 81% と書く。【抜粋で確認 RC2】
- Yoganarasimhan, Barzegary, Pani「Design and Evaluation of Optimal Free Trials」（Management Science 69(6), 2023）: 大手 SaaS 企業の野外実験で、新規の利用者を 7・14・30 日の無料体験に無作為に割り当てた。「shorter trial lengths (surprisingly) maximize customer acquisition, retention, and profitability」。個人ごとに長さを変える方針は、全員 30 日の方針より購読が 6.8% 多い（作業論文の版では、全員 7 日が最良の一律の方針で、購読が 5.59% 増）。【抜粋で確認 YB1】
- **nu-tori への当てはめ**: RevenueCat の「長いほど転換が高い」は opt-out の数で、長い無料体験を選ぶアプリには価値が体験に時間のかかるものが多いという選択の偏りも入りうる。無作為化の実験（YB1）は逆の結果で、30 日が転換に有利とは言い切れない。30 日の価値（体重の傾向が見えるまでに日数が要る）を守るなら、30 日目の前に有料の判断をさせる場面（例えば 2〜3 週目の目安の見直しの通知）が要る。【本文からの読み取り】

## 問い2: 月額・年額の継続（1・3・6・12 か月）

### ヘルスケア／フィットネスの更新率（RevenueCat、2026 年の基準）

- 月額の初回の更新率: 25 パーセンタイル 46%、中央値 57%、75 パーセンタイル 68%。「Health & Fitness | 46% | 57% | 68%」。カテゴリの中央値は 42%（Social & Lifestyle）〜61%（Business）。データは 2025-08〜2026-07。【抜粋で確認 RC3】
- 年額の初回の更新率: 25 パーセンタイル 16%、中央値 25%、75 パーセンタイル 37%。「Health & Fitness | 16% | 25% | 37%」。年額の中央値はカテゴリで 23%（Productivity、Photo & Video）〜40%（Travel、Business）で、ヘルスケア／フィットネスは低い側。【抜粋で確認 RC3】
- RevenueCat 2026 のレポート本体では、月額の更新率の中央値（カテゴリをまたぐ幅）は、1 回目 53〜61%、2 回目 65〜77%、3 回目 73〜82%。節によって幅が少し違う（2 回目 72〜83%、3 回目 74〜86% と書く箇所もある）。【抜粋で確認 RC1】
- 同じ本体に「Health & Fitness (86.4%) and Productivity (85.6%) lead yearly retention」という数もあるが、何の率か（更新の時期を迎えた人のうち自動更新をオンのままの人の割合など）が抜粋からは分からない。【抜粋で確認 RC1。定義は未確定】
- RevenueCat 2026 の 10 分でわかるブログ: 年額の解約のうち 35% が最初の月に起きる。【抜粋で確認 RC7】

### 3 か月・6 か月・12 か月

- 6 か月: 月額の継続の中央値 14〜26%、上位 4 分の 1 は 30〜50%（カテゴリをまたぐ幅。週額は 3〜6%）。【抜粋で確認 RC1】
- 12 か月: 月額の中央値 6〜14%、上位 4 分の 1 は 11〜25%。年額は 20〜40%。全体の中央値は前年から下がり、年額 31%→28%、月額 10%→8%、週額は約 1%。【抜粋で確認 RC1, RC7】
- Adapty 2026: 無料体験から入った人の 380 日目の継続は、年額 19.9%、月額 14.2%、週額 5.5%。ヘルスケア／フィットネスの初回の更新の継続（R1）は **30.3% で全カテゴリの最下位**（全体の平均 59.2%。2 回目 45.1%、3 回目 37.1%）。ヘルスケア／フィットネスは年額の売上が多いので、R1 は年額の初回の更新に引っ張られていると読める。【抜粋で確認 AD1, AD2。読みは本文からの読み取り】
- 3 か月目の推計（月額）: 3 か月目の初めに残っている＝初回と 2 回目の更新を通った人。ヘルスケア／フィットネスの初回（46・57・68%）に、カテゴリをまたぐ 2 回目の中央値の幅の中ほど（約 65〜77%）を掛けると、**下位 約 30%、中央 約 40%、上位 約 52%**。2 回目の更新率はヘルスケア／フィットネスだけの数ではないので、粗い推計。【本文からの読み取り（RC1, RC3 の掛け算）】
- ヘルスケア／フィットネスだけの 3・6・12 か月の継続の数は見つからなかった。【本文を探したが記述なし（revenuecat.com、adapty.io を検索）】

### 日本・Asia-Pacific

- RevenueCat 2024: 日本は 1 年目の継続で世界の首位。「Japan leads the world in Year 1 retention, with a whopping 42% for annual, 26% for monthly, and 10% for weekly subscriptions」。初回の更新率の中央値は日本 62%、北米 58%。【抜粋で確認 RC4】
- RevenueCat 2026: 初回の更新は北米と Asia-Pacific が高く、3 回目までに差は縮まる。Asia-Pacific は月額の再加入（reactivation）が 24% で最も高く、年額は 5.1%。日本だけの数は 2026 年版の抜粋に無い。【抜粋で確認 RC1】
- RevenueCat 2026 の中の Mojo の寄稿: 日本では、社会的証明と無料・有料の比較の表を載せた長いペイウォールが、米国風の対話型のペイウォールより 20% 超よかった。【抜粋で確認 RC1】
- **nu-tori への当てはめ**: 2024 年の日本の数は全体より高く、2026 年の全体の数は下がっている。日本の 2026 年の水準は、全体と 2024 年の日本の間のどこかと考えるのが無難。【本文からの読み取り】

## 問い3: ダウンロードから無料体験・有料

- RevenueCat 2026: ダウンロード→無料体験の中央値は、ヘルスケア／フィットネス 6.9%（教育 6.5%、ユーティリティ 6.5%）、上位は 23% 超。【抜粋で確認 RC1】
- RevenueCat 2026: 35 日目までのダウンロード→有料の中央値は、ヘルスケア／フィットネス 2.9%。iOS では 3.5% で首位（教育 3.1%、ビジネス 3.0%）。【抜粋で確認 RC1】
- RevenueCat 2026: Asia-Pacific のダウンロード→無料体験の中央値 5.7%（上位 4 分の 1 は 13.5% 超）、35 日目のダウンロード→有料の中央値 2.4%（上位 4 分の 1 は 5.1% 超）。北米の 35 日目のダウンロード→有料の中央値は 2.56%。【抜粋で確認 RC1, RC7】
- RevenueCat 2026: ハードペイウォールの 35 日目の転換の中央値は 10.7%、フリーミアムは 2.1%。抜粋では「trial-to-paid」と書かれるが、数の大きさからはダウンロード→有料と読むのが自然。【抜粋で確認 RC7。定義は未確定】
- RevenueCat 2024: 日本と韓国のダウンロード→有料は EMEA より良く、どちらも 2% を少し超える。【二次情報の抜粋 X2（RevenueCat 2024 を引く検索の要約）】
- RevenueCat 2026: ヘルスケア／フィットネスは、払った人あたりの実現 LTV が 1 か月で中央値 24.23 ドル（上位 4 分の 1 は 39.00 ドル超）、1 年で 35.64 ドル。【抜粋で確認 RC1】
- Apple の App Store Connect の「Peer group benchmarks」は、同じカテゴリ・同じ事業の形（無料・フリーミアム・有料）のアプリの 25・50・75 パーセンタイルと比べて、転換率、1・7・28 日目の継続、**35 日目のダウンロード→有料（Day 35 download-to-paid conversion）**、35 日目のダウンロードあたりの収益、払った人あたりの収益を見せる。値には少しノイズを足す。公開の文書に数そのものは無い。【抜粋で確認 AP1】
- **nu-tori への当てはめ**: RevenueCat の「35 日目のダウンロード→有料」と Apple の「Day 35 download-to-paid」は同じ形の指標で、nu-tori は公開後に自分の peer group の値を App Store Connect で見られる。30 日の無料体験は 35 日の窓にぎりぎり収まるので、nu-tori では 30 日目の判断のあとの数日しか入らない。比べるときは、自分の数は「インストールから 40 日」の窓でも出しておくとよい。【本文からの読み取り（AP1、RC1 から）】

## 問い4: 日本の価格、返金と解約

- RevenueCat 2026: 「Health & Fitness clusters at $39.94 yearly and $9.99 monthly」。月額の中央値の全体は 4.99〜9.99 ドルで、教育・ヘルス・ソーシャルが 9.99 ドルで高い。【抜粋で確認 RC1】
- Adapty 2026: 日本の年額の平均は世界で最も高い 54.59 ドル（カテゴリ別ではない）。日本・メキシコ・トルコが App Store のサブスクの収益で最も伸びている市場。【抜粋で確認 AD1】
- Adapty 2026: ヘルスケア／フィットネスは年額が売上の 60.6% を占める唯一のカテゴリ。RevenueCat 2026 の抜粋には「Health & Fitness captures 68% from annual plans」と「Health & Fitness is monthly-heavy (68%)」の両方が出て、食い違う。【抜粋で確認 AD1, RC1。食い違いは未解決】
- 日本の App Store での食事・体重のアプリの値段（2026-10-17 に取得）: あすけん プレミアム 月 580 円・年 4,400 円、プレミアム Plus 月 980 円・年 7,500 円、MacroFactor 月 1,540 円・年 9,200 円、カルシー 月 700〜1,600 円・年 3,900〜5,800 円、WiseMeal 月 1,500〜3,000 円。【このリポジトリの既存の調査 `docs/research/competitor-app-store-listings.md`、`docs/research/asken-macrofactor.md`（それぞれ App Store のページの本文で確認済み）】
- 返金: RevenueCat 2026 の価格帯別の返金率の中央値は、安い 2.7%、中 3.9%、高い 4.5%。ヘルスケア／フィットネスだけの 2026 年の数は見つからなかった。2025 年版では「Education and health & fitness apps have the highest refund rates, at 4.86% and 4.71% respectively」。【抜粋で確認 RC1, RC5】
- 解約の理由と時期: 年額の解約の 35% は最初の月（RC7）。1 年目の年額の解約は 2025 年の約 56% から 2026 年は約 72% に悪化した、とする抜粋もある。【抜粋で確認 RC7】

## 問い5: Sean Ellis の PMF のテスト（本人の文から）

- 問いと線（2009 年、Venture Hacks のインタビュー）: 「what percentage of people are telling me that they'd be very disappointed if they could no longer use it?」「If you're above 40% of the people saying they'd be very disappointed, I tend to say you've found product/market fit」。線は「40% を超える」。【抜粋で確認 SE1】
- 40% の出どころ（Ellis 本人のブログ startup-marketing.com）: 「Admittedly this threshold is a bit arbitrary, but I defined it after comparing results across nearly 50 startups」。のちの版では「nearly 100 startups」。【抜粋で確認 SE2】
- 回答の数: 「I look for around 30 responses as a minimum」。【抜粋で確認 SE2】
- 結果の向き（First Round Review で引かれた Ellis の観察）: 成長に苦しんだ会社はほぼいつも「とても残念」が 40% 未満で、強い牽引のある会社はほぼいつも超えていた。【抜粋で確認 SE4】
- 聞く相手（Ellis の Substack「Is Product/Market Fit Hiding in Your User Base?」）: 「I generally recommend surveying a random sample of people who have used the product within the last couple of weeks and have reached an activated state」。価値を体験していない登録者に聞いても意味が薄い、とも書く。【抜粋で確認 SE3】
- 40% 未満のとき（同じ Substack）: 「とても残念」と答えた少数の人に、合う層・使い方・activation の体験の手がかりがある。40% に届くまでは支出を抑え、その割合を上げることに資源を集める、とする。【抜粋で確認 SE3, SE2】
- 点数が高いのに継続が悪いとき（Ellis の Substack「High PMF Score, but Low Retention?」）: 継続の測り方（起点）と、回答の集め方の偏りをまず疑う。【抜粋で確認 SE3】
- 選択肢の文言（「Very disappointed / Somewhat disappointed / Not disappointed / N/A – I no longer use it」）と「使わなくなった人を分母から除く」扱いは、解説記事の抜粋にだけ出て、Ellis の原文の抜粋では確かめられなかった。25〜40% を「有望」とする段階の分け方は、解説記事の独自のもので Ellis のものではない。【二次情報の抜粋 X3】
- Superhuman（Rahul Vohra、First Round Review）: 最初 22% → 1 年足らずで 58%。満足している層と、迷っている層（somewhat disappointed）のうち主な利点が同じ人を分けて読む方法。【二次情報の抜粋 X4（First Round Review を引く要約。一次の抜粋では数は確かめていない）】

## 問い6: 継続の曲線が平らになることを PMF の兆しとみる指針

- a16z「Retention Is All You Need」（AI の製品の継続、一次の出版物）: 曲線は「多くは 3 か月目のあたり」で平らになり始め、時期よりも最後に平らになることが長期の収益の継続に効く。月額の契約では平らになることを直接の PMF の兆しとみる一方、年額の契約は弱い継続を隠しうる。【抜粋で確認 A1】
- a16z のマーケットプレイスの記事: 曲線は理想的には 6〜12 か月の間に平らになる。【抜粋で確認 A2】
- a16z「Do You Have Lightning In a Bottle?」（Bryan Kim、ソーシャルのアプリ向け）: 日ごとの継続の目安を Great 70/50/30%（1/7/30 日目）、Good 60/40/25%、OK 50/35/20% とし、曲線の傾きは 7〜14 日目に緩み、20 日目で平らになることが多い。通知で早い継続を押し上げた製品は 7〜30 日目に急に落ちる、とも書く。**ソーシャルのアプリの基準で、食事の記録のアプリにそのままは当てはまらない**。【抜粋で確認 A3。当てはめは本文からの読み取り】
- Andrew Chen: 「healthy retention curves that flatten out」を PMF の意味として書き（The Adjacent User Theory）、それで終わりではなく、曲線はまだ上げられると続ける。Mixpanel のブログは Chen の言葉として、ゼロに落ちる曲線は PMF が無く、ゼロでない値で平らになる曲線を目指す、と引く。【抜粋で確認 AC1（andrewchen.com）。Mixpanel 経由の部分は二次情報の抜粋 X5】
- Amplitude（製品分析の会社の自社の文書）: 2025 年の Product Benchmark Report（2,600 社超）で、7 日目に元の集団の 7% が戻れば activation で上位 25% に入り、3 か月の継続をよく予測する。7 日の activation の上位の 69% は 3 か月の継続でも上位。ヘルスケアの会社の 1 か月目の継続は全体より 45% 低い。【抜粋で確認 AM1。数はアプリの日々の利用の継続で、課金の継続ではない】
- Sean Ellis: 登録の日を起点にした曲線は、価値を体験しなかった人が多く混ざって平らにならないことが多い。起点を activation の時点に変えると平らな部分が見えることが多い。【抜粋で確認 SE3】
- **nu-tori への当てはめ**: 課金の継続（更新率）と、使う継続（朝の体重・食事の写真を続けるか）の 2 本の曲線を分けて見る。使う継続の起点は「初めて目安の kcal の見直しを受けた日」のような activation にすると、Ellis の指摘する混ざりを避けられる。【本文からの読み取り】

## 出典

検索の抜粋で読んだページ（本文は直接読めていない）。

- RC1: RevenueCat「State of Subscription Apps 2026」 https://www.revenuecat.com/state-of-subscription-apps （カテゴリ別のページ例: https://www.revenuecat.com/state-of-subscription-apps-2026-business ）
- RC2: RevenueCat「How long should your free trial be? Data from 17,000+ apps」 https://www.revenuecat.com/blog/growth/free-trial-length
- RC3: RevenueCat「Average Subscription Renewal Rates by App Category (2026 Benchmarks)」 https://www.revenuecat.com/blog/growth/average-subscription-renewal-rates-by-app-category
- RC4: RevenueCat「State of Subscription Apps 2024」 https://www.revenuecat.com/state-of-subscription-apps-2024
- RC5: RevenueCat「State of Subscription Apps 2025」 https://www.revenuecat.com/state-of-subscription-apps-2025
- RC6: RevenueCat Community「Start of Free Trial period without automatic subscription」 https://community.revenuecat.com/general-questions-7/start-of-free-trial-period-without-automatic-subscription-5821
- RC7: RevenueCat「The State of Subscription Apps in 10 minutes: lessons, trends, and benchmarks for 2026」 https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026 （日本語版 https://www.revenuecat.com/jp/blog/growth/subscription-app-trends-benchmarks-2026 ）
- AD1: Adapty「State of In-App Subscriptions 2026」 https://adapty.io/state-of-in-app-subscriptions/ と https://adapty.io/blog/mobile-app-monetization-2026/
- AD2: Adapty「In-app subscription benchmarks for Health & Fitness apps」 https://adapty.io/blog/health-fitness-app-subscription-benchmarks/
- AD3: Adapty「State of Paywalls 2026」 https://adapty.io/state-of-paywalls/
- CM1: ChartMogul「The SaaS Conversion Report」 https://chartmogul.com/reports/saas-conversion-report/
- YB1: Yoganarasimhan, Barzegary, Pani「Design and Evaluation of Optimal Free Trials」Management Science 69(6), 2023, https://pubsonline.informs.org/doi/10.1287/mnsc.2022.4507 （著者の PDF https://faculty.washington.edu/hemay/Free_Trial.pdf 、作業論文 https://arxiv.org/abs/2006.13420 ）
- AP1: Apple「Peer group benchmarks」App Store Connect Analytics ヘルプ https://developer.apple.com/help/app-store-connect-analytics/benchmarks/peer-group-benchmarks/
- SE1: Venture Hacks「How to bring a product to market / A very rare interview with Sean Ellis」（2009） https://venturehacks.com/sean-ellis-interview
- SE2: Sean Ellis, startup-marketing.com（「The Startup Pyramid」ほか、2009 年ごろ） https://www.startup-marketing.com/ 、https://www.startup-marketing.com/getting-to-product-market-fit/
- SE3: Sean Ellis（Substack）「Is Product/Market Fit Hiding in Your User Base?」 https://seanellis.substack.com/p/is-productmarket-fit-hiding-in-your 、「High PMF Score, but Low Retention? Fixing the Hidden Problem」 https://seanellis.substack.com/p/high-pmf-score-but-low-retention
- SE4: First Round Review「How Superhuman Built an Engine to Find Product/Market Fit」 https://review.firstround.com/how-superhuman-built-an-engine-to-find-product-market-fit/
- A1: a16z「Retention Is All You Need」 https://a16z.com/ai-retention-benchmarks/
- A2: a16z「GMV Retention: The Marketplace Metric Most Ignore」 https://a16z.com/gmv-retention-the-marketplace-metric-most-ignore/
- A3: a16z「Do You Have Lightning In a Bottle? How to Benchmark Your Social App」 https://a16z.com/do-you-have-lightning-in-a-bottle-how-to-benchmark-your-social-app/
- AC1: Andrew Chen「The Adjacent User Theory」 https://andrewchen.com/the-adjacent-user-theory/
- AM1: Amplitude「The 7% Retention Rule Explained」 https://amplitude.com/blog/7-percent-retention-rule 、「Product Benchmarks for Healthcare Companies」 https://amplitude.com/benchmarks/healthcare

二次情報（参考に留め、根拠にしていない）。

- X1: kirro.io、vmobify.com などの SaaS の無料体験の解説（First Page Sage の数を引く） https://kirro.io/free-trial-conversion-rate 、https://vmobify.com/blog/free-trial-conversion-rate
- X2: RevenueCat 2024 の日本・韓国のダウンロード→有料を引く検索の要約（一次のページの抜粋は得られず）
- X3: Sean Ellis のテストの解説記事（例 https://learningloop.io/glossary/sean-ellis-score 、https://formbricks.com/blog/product-market-fit-survey-questions ）
- X4: Superhuman の数の要約（例 https://www.mindtheproduct.com/the-product-market-fit-engine-by-rahul-vohra/ ）
- X5: Mixpanel「What 14 startup investors & advisors taught us about chasing (and finding) product-market fit」 https://mixpanel.com/blog/what-14-startup-investors-and-advisors-taught-us-about-chasing-and-finding-product-market-fit/
