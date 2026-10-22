# App Store のサブスクを売る前に要る事実（特定商取引法、課金画面、退会、請求の猶予、Sandbox、ファミリー共有、価格の出し分け）

調査日: 2026-10-17
対象: 課金を入れる前の確認（ブランチ `billing-shape`、ADR-0024「無料版と広告を作らず、30日の無料体験のあとはサブスクにする」）。nu-tori は日本の個人開発者が出す iPhone アプリで、月額と年額のサブスク（自動更新）を App Store のアプリ内課金だけで売る。無料体験は支払いの登録なしの30日で、サーバーが日数を数える（App Store の Introductory Offer は使わない）。StoreKit 2 と App Store Server Notifications V2 を自前のサーバー（Cloudflare Workers）で受ける。

> **確認の方法と限界**
> - Apple の開発者向けドキュメント（StoreKit、App Store Server Notifications、App Store Server API、HIG）は、同じ内容の JSON（`https://developer.apple.com/tutorials/data/<パス>.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。App Review Guidelines、Apple Developer Program License Agreement（以下 DPLA）、developer.apple.com/app-store/subscriptions/、アカウント削除の文書、App Store Connect ヘルプは HTML を取得して本文を読んだ。
> - 法令は e-Gov 法令 API（v2）で、調査日に施行されている版を取得した（特定商取引に関する法律は 2026-08-12 施行の改正版、施行規則は 2026-05-21 施行の改正版）。消費者庁の「特定商取引法ガイド」（no-trouble.caa.go.jp）は HTML を、「通信販売の申込み段階における表示についてのガイドライン」は PDF を取得して本文を読んだ。
> - App Store の利用規約（Apple Media Services 利用規約、日本版）は apple.com/jp の HTML を読んだ（最終更新日 2026年9月14日）。
> - 本文で確かめた主張は「本文で確認」と書き、短い原文を添える。本文の記述から推し量ったもの（nu-tori への当てはめの多く）は「本文からの読み取り」と書き、何から読み取ったかを添える。探しても記述が無かったものは「本文を探したが記述なし」と書き、探したページを添える。
> - 英語の本文は原文のまま引用し、訳はこの文書で付けた。**この文書は法律の専門家の見解ではない。** 特定商取引法の当てはめ（App Store の商品ページやアプリ内の課金画面が「広告」や「特定申込み」の画面に当たるか）は、消費者庁の文書に App Store を名指しした記述がなく、最後は事業者の判断になる。
> - App Store Connect の**実アカウントの画面は見ていない**。審査で実際にどう判断されるかは確かめようがないので、書かれた基準だけを書いた。
> - 二次情報（解説ブログ、まとめ記事、課金 SaaS の文書、開発者フォーラムの投稿）は根拠にしていない。検索の途中で目に入ったものはあるが、主張の根拠には使っていない。

## 結論の要約

- **問い1（特定商取引法）**: **要る、と読むのが自然**。日本の App Store では、Apple（iTunes株式会社）は開発者の**代理人**で、売買の当事者ではない（DPLA の Exhibit A と App Store の利用規約で本文で確認）。有料の情報配信のような役務も通信販売の対象になる（消費者庁 Q&A の A1 で本文で確認）。App Store のアプリ内課金に限った適用除外は見つからなかった（本文を探したが記述なし）。**住所と電話番号は「請求があれば遅滞なく開示する」と広告に書き、実際に遅滞なく出せる仕組みを持てば、表示を省ける**（法 11 条ただし書、消費者庁 Q&A の A17 で本文で確認）。ただし「遅滞なく」は「申込みの意思決定に先立って十分な時間的余裕をもって」の意味で、氏名は戸籍上の氏名（屋号だけは不可）。省けないもの（申込みの撤回・解除のうち返品の事項など）もある。Apple 自身が日本の開発者向けに特定商取引法の表示を求める文書は見つからなかった。
- **問い2（課金画面）**: Apple が課金画面に求めるのは、**サブスクの名前、期間、期間中に得られるもの、請求額（最も目立つ価格の要素として）、購入の復元**、そして**アプリ内と App Store のメタデータに利用規約（Terms of Use）とプライバシーポリシーへのリンク**（DPLA Schedule 2 の 3.8(b)、subscriptions ページ、HIG で本文で確認）。**独自の EULA を出さなければ Apple の標準 EULA が適用される**（本文で確認）が、その標準 EULA へのリンクで「Terms of Use へのリンク」の要件を満たすと明記した Apple の文書は見つからなかった。**サーバーが数える無料体験を明示的に許す・禁じる Apple の文書は見つからなかった**。HIG は「無料で試せるようにすることを考える。freemium、metered paywall、free trial など」と書いており、支払いの登録なしの無料期間そのものは禁じられていないと読める。ただし 3.1.2(a) は、サブスクの無料体験を「App Store Connect に情報を出して」提供できると書いている。このため課金画面では「**無料体験**」を App Store の無料体験と取り違えさせない書き方（サブスクを買うとすぐに請求されること、無料体験の残りの日はどうなるか、無料体験が終わると何が使えなくなるか）が要る（本文からの読み取り）。特定商取引法の面では、無料期間のあとに**自動で有料に移る形ではない**ので、消費者庁ガイドラインの「無償期間から自動的に有償に移るサブスク」の表示の要件にはそのまま当たらない（本文からの読み取り）。
- **問い3（退会）**: Apple は「サブスクがある人には、**請求は Apple を通じて続くことを知らせ、先に解約するよう求める**」と書き、`showManageSubscriptions`（または `https://apps.apple.com/account/subscriptions/`）で解約の画面に案内する方法を示している。サブスクの期限に合わせて削除を予約する形も、**すぐ削除する選択肢もあわせて出すなら**認められる（本文で確認）。返金の申請の案内（`beginRefundRequest`）も挙げている。
- **問い4（請求の猶予）**: 更新の請求に失敗すると、**最大60日の Billing Retry** に入る（本文で確認）。**Billing Grace Period** は App Store Connect でアプリ単位にオンにし、**3日・16日・28日**から選ぶ（週額は最大6日）。「すべての更新」か「有料から有料の更新だけ」か、Sandbox だけか本番と Sandbox の両方か、も選ぶ（本文で確認）。通知は `DID_FAIL_TO_RENEW`（猶予ありなら subtype `GRACE_PERIOD`）、`GRACE_PERIOD_EXPIRED`、`DID_RENEW`（subtype `BILLING_RECOVERY`）、`EXPIRED`（subtype `BILLING_RETRY`）（本文で確認）。
- **問い5（Sandbox）**: **TestFlight は Sandbox を使う**（本文で確認）。**審査中のアプリも Sandbox を使う**と読める記述がある（受領証の検証の文書が、審査中は sandbox の URL を使う、本番の URL で検証して 21007 なら sandbox で検証し直せば「審査中、公開後」も URL を切り替えずに済む、と書く。本文で確認）。審査では課金が動くことが求められる（2.1(b)）。したがって**本番のサーバーは Sandbox の取引を受け付ける必要がある**（本文からの読み取り）。通知は本番と Sandbox で別の URL を設定でき（同じ URL でもよい）、通知の `environment` で見分けられる。Sandbox の通知は、Sandbox の URL を設定したときだけ届く（本文で確認）。
- **問い6（ファミリー共有）**: **戻せない**。「once you turn on Family Sharing for an In-App Purchases in App Store Connect, you can't turn it off」（App Store Connect ヘルプと subscriptions ページで本文で確認）。
- **問い7（価格の出し分け）**: **1つのサブスクグループに価格の違う商品を並べ、ユーザーごとに見せる商品を変えることを、明示的に許す・禁じる Apple の文書は見つからなかった**。関係する決まりは、「同じものの別の形に、うっかり複数入れないこと」（3.1.2(b)）、「巧妙な方法で値上げしない、意図しない購入をさせない」（5.6）、「明らかなぼったくりの価格は配布しない」（3.1 の前文）。一方で、**グループの商品は App Store の商品ページのアプリ内課金の欄に出て**、加入者はサブスクの管理の画面で同じグループの別の選択肢に乗り換えられる（本文で確認）。このため、出し分けた価格の商品も、ユーザーから見えると考えておく必要がある（本文からの読み取り）。

## 問い1: 特定商取引法に基づく表記は要るか

### 誰が売り手か（日本の App Store）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 日本のユーザーへの配布で Apple は何の立場か | iTunes KK（iTunes株式会社）が、民法 643 条に基づく開発者の**代理人**。「You appoint iTunes KK as Your agent pursuant to Article 643 of the Japanese Civil Code for the marketing and End-User download of the Licensed and Custom Applications by End-Users located in the following region: Japan」 | 本文で確認 | DPLA Schedule 2 Exhibit A, Section 1 【AP2】 |
| Exhibit A, Section 2（Apple Distribution International が commissionaire）にも Japan があるが | Section 2 の Japan には `***` が付き、注は「Solely applicable to non-resident Developers.」。日本に住む開発者には Section 1（iTunes KK が代理人）が当たると読める。DPLA の Exhibit B 6(A) も「Where You designate iTunes KK to allow access to … End-Users in Japan」と、日本に住む開発者の日本向け配布を iTunes KK の前提で書いている | 本文からの読み取り（`***` の注と Exhibit B 6(A) から） | 同上 |
| App Store の利用規約は誰を売買の当事者としているか | 「Appleはアプリプロバイダの代理人としてApp Storeを運営しますが、お客様とアプリプロバイダとの間の売買契約またはユーザー契約の当事者ではありません」。Apple Distribution International または Apple Services Pte. Ltd. の客の場合だけ、それらが「最終販売責任を負う商業者」になる。日本のユーザーの Apple の窓口は iTunes株式会社 | 本文で確認 | Apple Media Services 利用規約（日本、最終更新日 2026年9月14日）【AP8】 |
| アプリ内のサブスクも同じか | 利用規約は「アプリ」にアプリ内課金を含めている（「『アプリ』には、…当該アプリやApp Clip内で利用可能なアプリ内課金…が含まれ」） | 本文で確認 | 同上 |

### 特定商取引法の通信販売に当たるか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 通信販売の定義 | 「販売業者又は役務提供事業者が郵便その他の主務省令で定める方法…により売買契約又は役務提供契約の申込みを受けて行う…役務の提供であつて電話勧誘販売に該当しないもの」 | 本文で確認 | 法 2 条 2 項【J1】 |
| 有料のデジタルのサービスは対象か | 「『有料の情報配信サービス』が役務を有償で提供する契約に基づく場合は、特定商取引法の規制対象になります」 | 本文で確認 | 消費者庁 通信販売広告Q＆A A1【J3】 |
| 個人でも表示は要るか | 「法人であれ個人であれ氏名又は名称を表示することが必要です」 | 本文で確認 | 同 A15【J3】 |
| プラットフォームの上で売る個人事業者は | Q18 は「通信販売の取引の場を提供するプラットフォーム事業者」の住所・電話番号を、一定の条件で個人事業者が表示に使える場合を書いている。プラットフォームで売る個人事業者にも表示の義務があることが前提になっている | 本文からの読み取り（A18 の書き方から） | 同 A18【J3】 |
| App Store のアプリ内課金に限った適用除外や、App Store を名指しした記述 | 見つからなかった | 本文を探したが記述なし（法 26 条の適用除外の書きぶりは確かめていない。消費者庁の通信販売のページ、通信販売広告Q＆A、申込み段階のガイドラインを探した） | 【J1】【J2】【J3】【J4】 |
| Apple は日本の開発者に特定商取引法の表示を求めているか | 求める文書は見つからなかった。App Store Connect ヘルプで目に入ったのは EU のデジタルサービス法の trader の要件のページ（「Manage European Union Digital Services Act trader requirements」）で、日本のものは見当たらなかった | 本文を探したが記述なし（App Store Connect ヘルプの目次、DPLA、App Review Guidelines） | 【AP2】【AP3】 |

**nu-tori への当てはめ（本文からの読み取り）**: 日本のユーザーに対しては開発者が役務提供事業者で、Apple は代理人にとどまる。有料のサブスクは「有料の情報配信サービス」と同じく役務の有償提供に当たり、反復して売るので事業として行うことになる。消費者庁の Q3 は、インターネット通販で「その広告に基づき通信手段により申込みを受ける意思が明らかであり、かつ、消費者がその表示を受けて購入の申込みをすることができるもの」を広告に当たるとしている。アプリ内の課金画面（価格を見せて購入ボタンを押させる画面）はこれに当たると考えるのが安全で、表示はアプリ内（課金画面から辿れる場所）と公開のページ（`site/`）に置くのが自然。

### 表示する事項

| 事項 | 根拠 | 確かさ |
|---|---|---|
| 価格（役務の対価） | 法 11 条 1 号 | 本文で確認【J1】 |
| 代金の支払の時期と方法 | 法 11 条 2 号 | 本文で確認【J1】 |
| 役務の提供時期 | 法 11 条 3 号 | 本文で確認【J1】 |
| 申込みの期間の定めがあればその内容 | 法 11 条 4 号 | 本文で確認【J1】 |
| 申込みの撤回・解除に関する事項 | 法 11 条 5 号。「顧客にとつて見やすい箇所において明瞭に判読できるように表示」（規則 24 条 3 号） | 本文で確認【J1】【J2】 |
| 氏名（名称）、住所、電話番号 | 規則 23 条 1 号。個人は「戸籍上の氏名又は商業登記簿に記載された商号」で、屋号やサイト名だけは不可（A16） | 本文で確認【J2】【J3】 |
| 対価のほかに負担する金銭（通信料など）があればその内容と額 | 規則 23 条 4 号 | 本文で確認【J2】 |
| ソフトウェアの動作に要る環境 | 規則 23 条 6 号（「プログラムを電子計算機に備えられたファイルに記録し、若しくは記録させる役務を提供する場合」） | 本文で確認【J2】 |
| 2回以上続けて契約する必要があるときは、その旨と金額、契約期間その他の条件 | 規則 23 条 7 号。自動更新のときの書き方は Q&A の A21 | 本文で確認【J2】【J3】 |

### 住所と電話番号を「請求があれば遅滞なく開示」にできるか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 条文 | 「当該広告に、請求により、これらの事項を記載した書面を遅滞なく交付し、又はこれらの事項を記録した電磁的記録を遅滞なく提供する旨の表示をする場合には、…これらの事項の一部を表示しないことができる」 | 本文で確認 | 法 11 条ただし書【J1】 |
| 個人事業者の住所・電話番号 | **できる**。「消費者からの請求によって、広告表示事項を記載した書面又は電子メール等を『遅滞なく』提供することを広告に表示し、かつ、実際に請求があった場合に『遅滞なく』提供できるような措置を講じている場合には、事業者の住所及び電話番号の表示を省略することも可能です」 | 本文で確認 | 消費者庁 通信販売広告Q＆A A17【J3】 |
| 「遅滞なく」の意味 | 「販売方法等の取引実態に即して、申込みの意思決定に先立って十分な時間的余裕をもって提供されることをいいます」。インターネット・オークションのように申込みの期間が短いものでは「困難であると考えられます」 | 本文で確認 | 同 A17、通信販売のページ【J3】【J4】 |
| 氏名も省けるか | 省ける（A15 に同じ条件の記述）。ただし 4 号（申込みの期間）、返品に関する事項、前払いのときの支払時期などは省けない（消費者庁の表の「省略できない」） | 本文で確認 | 同 A15、通信販売のページの表【J3】【J4】 |
| 省くときに要るもの | 規則 25 条。価格（対価）を全部表示するなら、2 号・3 号・5 号・6 号の一部を省ける。ただし前払いなら支払時期は省けない（25 条 2 項ただし書） | 本文で確認 | 規則 25 条【J2】 |
| 開示を有料にするなら | その額を表示する（規則 23 条 9 号） | 本文で確認 | 【J2】 |
| 私書箱 | 住所の表示にならない（A19） | 本文で確認 | 【J3】 |
| バーチャルオフィス・プラットフォームの住所 | 3つの条件（取引がそのプラットフォームの上で行われる、連絡先として機能することに合意がある、運営者が本人の現住所と本人名義の電話番号を把握し確実に連絡が取れる）を満たせば足りる（A18） | 本文で確認 | 【J3】 |

**nu-tori への当てはめ（本文からの読み取り）**: サブスクの代金は App Store で前払い（期間の初めに請求）なので、支払時期は省けない。価格・期間・支払時期・提供時期・解約の方法は表示し、住所と電話番号（必要なら氏名も）を「請求があれば遅滞なく電子メールで開示する」とする形が、条文と Q&A の上では取れる。開示の請求の窓口（問い合わせのメールアドレスなど）を表示に書き、請求から短い時間で返す運用が要る。`docs/research/privacy-policy.md` の個人情報保護法 32 条の住所の扱い（「求めに応じて遅滞なく回答する」）と同じ考え方で揃えられる。

### 課金の最後の画面（法 12 条の 6）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 条文 | 事業者「若しくはそれらの委託を受けた者」が定める手続で顧客の画面に表示して行う申込み（特定申込み）では、その画面に分量と、11 条 1〜5 号の事項を表示する。申込みになることや表示事項を誤認させる表示をしてはならない | 本文で確認 | 法 12 条の 6【J1】 |
| サブスクのときの表示 | 「サブスクリプションにおいて見受けられるような、無償又は割引価格で利用できる期間を経て当該期間経過後に有償又は通常価格の契約内容に自動的に移行するような場合には、有償契約又は通常価格への移行時期及びその支払うこととなる金額が明確に把握できるようにあらかじめ表示する必要がある」。無期限のサブスクは「１年単位の支払額など、一定期間を区切った支払総額を目安として明示する」 | 本文で確認 | 申込み段階のガイドライン【J5】 |
| 「お試し」の強調 | 「『お試し』や『トライアル』などと殊更に強調する表示は、…容易に解約できるなどと消費者が認識する可能性が高いため、これに反して、実際には定期購入契約となっていたり、解約に条件があり容易に解約できなかったりする場合には同号に該当するおそれが強い」 | 本文で確認 | 同【J5】 |
| 最終確認画面で別の箇所を参照させてよいか | 「最終確認画面に参照の対象となる表示事項及びその参照箇所又は参照方法を明示した上で、広告部分の該当箇所等を参照する形式とすることは妨げられない」 | 本文で確認 | 同【J5】 |
| App Store の購入のシートは「特定申込み」の画面か | 消費者庁の文書に記述なし。Apple は開発者の代理人なので、Apple の購入シートが「委託を受けた者が定める…手続」に当たる可能性はある。購入シートの中身は開発者が決められないので、アプリ内の課金画面（購入ボタンを押す直前の画面）に 12 条の 6 の事項を揃えておくのが安全 | 本文からの読み取り（条文の「委託を受けた者」と、代理人の関係から） | 【J1】【AP2】 |

## 問い2: 課金画面に求められること（App Review Guidelines 3.1.2 と関連の文書）

### Apple が求める表示

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 3.1.2(c) | 「Before asking a customer to subscribe, you should clearly describe what the user will get for the price. … Ensure you clearly communicate the requirements described in Schedule 2 of the Apple Developer Program License Agreement.」 | 本文で確認 | App Review Guidelines（Last Updated: October 16, 2026）【AP1】 |
| DPLA Schedule 2 の 3.8(b) | 「You clearly and conspicuously disclose to users the following information regarding Your auto-renewing subscription: Title of auto-renewing subscription, which may be the same as the in-app product name / Length of subscription / Price of subscription, and price per unit if appropriate / Links to Your Privacy Policy and Terms of Use must be accessible within Your Licensed Application.」 | 本文で確認 | DPLA Schedule 2 3.8(b)（October 13, 2026 版）【AP2】 |
| subscriptions ページの「sign-up screen」に要るもの | 「Subscription name and duration, and the content or services provided during the subscription period」「Full renewal price, shown clearly and prominently, and localized in available currencies」「A way for current subscribers to sign in or restore purchases」。さらに「your app and App Store metadata must include links to your Terms of Use and Privacy Policy」 | 本文で確認 | Auto-renewable subscriptions【AP4】 |
| 請求額の目立たせ方 | 「the amount that will be billed must be the most prominent pricing element in the layout」。年額なら年の総額を最も目立たせ、月あたりの換算や割引の率は「subordinate position and size」に置く | 本文で確認 | 同【AP4】 |
| 無料体験の表示（App Store の無料体験の場合） | 「In the purchase flow for a free trial, clearly indicate how long the free trial lasts and the price billed once the free trial is over.」。HIG は「make sure people know that when the free trial is over, a payment will be automatically initiated for the next subscription period」 | 本文で確認 | 【AP4】、HIG Apple In-App Purchase（2026-09-17 更新）【AP5】 |
| 管理と解約 | HIG: 「Always make it easy for customers to cancel an auto-renewable subscription.」。`showManageSubscriptions(in:)` の利用を勧める | 本文で確認 | 【AP5】 |
| 期間 | 3.1.2(a): 「the subscription period must last at least seven days and be available across all of the user's devices」。期間は 1週・1・2・3・6か月・1年 | 本文で確認 | 【AP1】、App Store Connect ヘルプ「Offer auto-renewable subscriptions」【AP6】 |

### Apple の標準 EULA で足りるか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 独自の EULA を出さないとき | 「In the event that You do not furnish Your own EULA for any Licensed Application to Apple, You acknowledge and agree that each End-User's use of that Licensed Application shall be subject to Apple's standard EULA」 | 本文で確認 | DPLA Schedule 2 4.2【AP2】 |
| App Store Connect の扱い | 「If you don't provide a custom EULA, the standard EULA is applied to your app and the license agreement link isn't shown on your App Store product page.」 | 本文で確認 | App Store Connect ヘルプ「Provide a custom license agreement」【AP6】 |
| 標準 EULA へのリンクで「Terms of Use へのリンク」の要件を満たすか | 満たすと明記した Apple の文書は見つからなかった | 本文を探したが記述なし（3.1.2、DPLA Schedule 2 3.8、subscriptions ページ、HIG、App Store Connect ヘルプの EULA と App information のページ） | 【AP1】【AP2】【AP4】【AP5】【AP6】 |

**nu-tori への当てはめ（本文からの読み取り）**: 標準 EULA はアプリの使用許諾で、標準 EULA が適用されること自体は確か。ただし nu-tori はアカウント、サーバーへの記録、LLM の推定、無料体験とサブスク切れの扱いといった、標準 EULA に書かれていないサービスの条件を持つ。特定商取引法の表示（問い1）と合わせて、自前の利用規約を `site/` に置き、課金画面と App Store のメタデータ（説明文）からリンクするのが、要件の読み違いの余地が少ない。

### サーバーが数える無料体験を課金画面にどう出すか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 3.1.2(a) の無料体験 | 「Auto-renewable subscription apps may offer a free trial period to customers by providing the relevant information set forth in App Store Connect.」 | 本文で確認 | 【AP1】 |
| サブスクでないアプリの時間制の無料体験 | 3.1.1: 価格 0 の非消耗型のアイテム「XX-day Trial」を使う形。「Prior to the start of the trial, your app must clearly identify its duration, the content or services that will no longer be accessible when the trial ends, and any downstream charges」 | 本文で確認 | 【AP1】 |
| HIG の無料での利用 | 「Consider letting people try your content for free before signing up. … For example, you might offer a freemium app, a metered paywall, or a free trial.」 | 本文で確認 | 【AP5】 |
| サーバーが数える無料期間を許す・禁じる記述 | 見つからなかった | 本文を探したが記述なし（3.1.1、3.1.2、subscriptions ページ、HIG） | 【AP1】【AP4】【AP5】 |
| 機能を自前の仕組みで開けることの禁止（3.1.1） | 「Apps may not use their own mechanisms to unlock content or functionality, such as license keys, augmented reality markers, QR codes, cryptocurrencies…」 | 本文で確認 | 【AP1】 |
| だますことの禁止 | 3.1.2(a): 「apps that attempt to trick users into purchasing a subscription under false pretenses or engage in bait-and-switch and scam practices; these will be removed」。5.6: 「trick them into making unwanted purchases」 | 本文で確認 | 【AP1】 |

**nu-tori への当てはめ（本文からの読み取り）**:
- 支払いの登録なしに最初の30日すべての機能を使える形は、HIG が挙げる freemium・metered paywall と同じく「買う前に無料で使える」形で、3.1.1 の「自前の仕組みで有料の機能を開ける」（ライセンスキーなどで、買ったものの代わりにする）とは違う。禁じる記述は見つからない。ただし 3.1.2(a) の「無料体験は App Store Connect に情報を出して」という一文を、審査がサブスクの無料体験は Introductory Offer を使うことと読む余地は残る。審査メモ（Notes for Review）に、無料体験はサーバーが数え、支払いの登録をさせず、自動でサブスクに移らないことを書いておくと説明がつく。
- 課金画面で取り違えが起きやすいのは、**無料体験中に「サブスクを始める」を押すとどうなるか**。Introductory Offer を使わないので、App Store の購入はその場で通常の価格の請求になる。課金画面には、(1) サブスクを買うとすぐに請求されること、(2) 無料体験の残りの日がどう扱われるか、(3) 無料体験が終わる日と、終わるとサブスク切れで何が残り何が使えなくなるか（体重の記録と過去の記録の見返しだけ）、を書く。3.1.1 がサブスクでない無料体験に求める「期間、終わったら使えなくなるもの、そのあとの料金」が、表示の中身の目安になる。
- 「無料体験」を App Store の購入シートや Apple の文書の「free trial」と同じものに見せない。とくに無料体験中の課金画面で「30日無料」を大きく出して購入ボタンを並べると、買えば30日無料になると読める。これは 3.1.2(a) の bait-and-switch や、消費者庁のガイドラインの「お試し」の強調（問い1）と同じ問題になりうる。
- 特定商取引法の面では、無料体験は自動でサブスクに移らないので、ガイドラインの「無償期間から有償に自動的に移行する」場合の表示（移行時期と金額）には当たらない。サブスクそのもの（自動更新）については、更新の時期と金額、1年あたりの支払額の目安、解約の方法を表示する。

## 問い3: 退会（アカウント削除）のときのサブスクの解約の案内

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 5.1.1(v) | 「If your app supports account creation, you must also offer account deletion within the app.」 | 本文で確認 | 【AP1】 |
| 課金の扱いを知らせる | 「If your app supports in-app purchases, help people understand how billing and cancellations will be handled.」 | 本文で確認 | Offering account deletion in your app【AP7】 |
| サブスクがある人 | 「If a person has an auto-renewable subscription, notify them that billing will continue through Apple and ask them to cancel their subscription before continuing. If you use App Store Server Notifications for auto-renewable subscriptions, you can verify the status of the person's subscription in real time, or use the Subscription Status API to identify subscription status.」 | 本文で確認 | 同【AP7】 |
| 案内の方法 | 「Use showManageSubscriptions in iOS 15 and iPadOS 15, or later, or provide this link to let people manage their subscriptions: https://apps.apple.com/account/subscriptions/」。返金は「beginRefundRequest … or provide this Apple Support link …: https://support.apple.com/118223」 | 本文で確認 | 同【AP7】 |
| 期限に合わせた削除の予約 | 「you can offer to schedule account deletion for a later date, aligned with the subscription's expiration, as long as there's also an option to delete the account immediately」。HIG も「If you offer a way to schedule account deletion, offer an option for immediate deletion as well.」 | 本文で確認 | 同【AP7】、HIG Managing accounts【AP5】 |
| HIG の書きぶり | 「Billing for an auto-renewable subscription continues through Apple until people cancel the subscription, regardless of whether they delete their account.」「After they delete their account, people need to cancel their subscription or request a refund.」 | 本文で確認 | HIG Managing accounts【AP5】 |
| 削除を難しくしない | 「apps that make it unnecessarily difficult for someone to delete their account will not pass review」。規制の強い業種でなければ、電話・メール・チャットを要求しない | 本文で確認 | 【AP7】 |
| Sign in with Apple | 「Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens.」 | 本文で確認 | 【AP7】 |

**nu-tori への当てはめ（本文からの読み取り）**: 退会の流れの中で、サーバーが持つサブスクの状態（通知で更新したもの）を見て、サブスク中なら「アカウントを消しても Apple の請求は続く。先に解約を」と知らせ、`showManageSubscriptions` を開くボタンを置く。Apple の文書は「解約してから先へ」と求めるが、解約しないと削除できないようにせよとは書いていない（「unnecessarily difficult」にしない）。削除を期限まで予約する形を出すなら、すぐ削除する選択肢も並べる。

## 問い4: Billing Grace Period と Billing Retry

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Billing Retry | 「If the customer's billing is invalid, the renewal fails and the user's subscription enters a billing retry state, where the App Store attempts to collect payment for up to 60 days.」。60日のうちに回復すると、回復した日が新しい請求日になる | 本文で確認 | Reducing involuntary subscriber churn【AP9】、subscriptions ページ【AP4】 |
| Billing Grace Period とは | 「Billing Grace Period lets subscribers whose auto-renewal failed due to a payment issue continue accessing your app's paid content for a period of time while Apple continues to attempt to collect payment.」。猶予のうちに回復すれば、有料の日数（1年で手数料が下がる計算）と収入が途切れない。猶予中の分の代金は取られない（「Payment for the provided full service during the grace period would not be collected.」） | 本文で確認 | App Store Connect ヘルプ「Enable billing grace period」【AP6】、【AP9】 |
| 選べる日数 | 「select a period of 3, 16, or 28 days to apply across all subscription products in your app」。週額は16日・28日を選んでも6日（「the actual grace period will only be 6 days」）。HIG・churn の文書も「3 or 6 days for a weekly subscription」「3, 16, or 28 days for monthly and longer subscriptions」 | 本文で確認 | 【AP6】【AP9】【AP4】 |
| 単位 | アプリ単位。商品ごとには選べない（「Configurability isn't available for individual subscription products.」） | 本文で確認 | 【AP6】 |
| ほかに選ぶもの | 対象: 「All Renewals」（無料のオファーから有料に移る更新を含む）か「Only Paid to Paid Renewals」。環境: 「Only Sandbox Environment」か「Production and Sandbox Environment」。変更は最大24時間で効き、これからの更新にだけ当たる | 本文で確認 | 【AP6】 |
| 例外 | 「Billing Grace Period doesn't apply for monthly subscriptions with a 12 month commitment.」 | 本文で確認 | 【AP6】 |
| 猶予中の義務 | DPLA: 「You must fulfill the offer during the entire subscription period, as marketed, including any Billing Grace Period You authorize」 | 本文で確認 | DPLA Schedule 2 3.8(c)【AP2】 |
| 通知（V2） | 「The subscription fails to renew and enters the billing retry period.」→ `DID_FAIL_TO_RENEW`（subtype なし）／猶予ありなら `DID_FAIL_TO_RENEW` + `GRACE_PERIOD`／「The subscription exits the billing grace period (and continues in billing retry).」→ `GRACE_PERIOD_EXPIRED`／「The billing retry successfully recovers the subscription.」→ `DID_RENEW` + `BILLING_RECOVERY`／「The subscription expires because the billing retry period ends without recovering the subscription.」→ `EXPIRED` + `BILLING_RETRY` | 本文で確認 | notificationType【AP10】 |
| 猶予の終わりの日時 | 更新の情報の `gracePeriodExpiresDate`（churn の文書は旧い `grace_period_expires_date_ms` で説明している） | 本文で確認（旧い名前の記述は churn の文書、`gracePeriodExpiresDate` は JWSRenewalInfoDecodedPayload の文書） | 【AP9】、JWSRenewalInfoDecodedPayload https://developer.apple.com/documentation/appstoreserverapi/jwsrenewalinfodecodedpayload |

**関連して見つけた食い違い**: App Store Connect ヘルプの「Offer auto-renewable subscriptions」は猶予を「either 6 or 16 days, depending on the subscription duration」と書いており、同じヘルプの「Enable billing grace period」（3・16・28日）と食い違う。設定の手順を書いたページと churn の文書の両方が 3・16・28 日なので、こちらを今の値と読んだ（本文からの読み取り）。

## 問い5: App Review と TestFlight は Sandbox か、本番のサーバーは Sandbox を受け付けるべきか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| TestFlight | 「TestFlight uses the sandbox environment for Apple In-App Purchases. Transactions and purchases that occur in the sandbox don't incur charges.」。App Store Connect ヘルプも「Apps downloaded from TestFlight will automatically operate in a sandbox environment.」。TestFlight ではサブスクが1日ごとに最大6回更新される | 本文で確認 | Testing at all stages of development with Xcode and the sandbox【AP12】、App Store Connect ヘルプ「Testing subscriptions and In-App Purchases in TestFlight」【AP6】 |
| App Review | 受領証の検証の文書: 「Use the test environment URL https://sandbox.itunes.apple.com/verifyReceipt when testing your app in the sandbox and while your app is in review.」「Verify your receipt first with the production URL; then verify with the sandbox URL if you receive a 21007 status code. This approach ensures you don't have to switch between URLs while your app is in testing, in review by App Review, or live in the App Store.」 | 本文で確認（ただし文書は非推奨の `verifyReceipt` についてのもの） | Validating receipts with the App Store【AP13】 |
| StoreKit 2 / V2 の文書に「審査は Sandbox」と書いてあるか | 見つからなかった | 本文を探したが記述なし（App Store Server Notifications の environment、App Store Server API、Testing at all stages、App Store Connect ヘルプの sandbox の概要） | 【AP10】【AP11】【AP12】【AP6】 |
| 審査で課金が動く必要 | 2.1(b): 「If you offer in-app purchases in your app, make sure they are complete, up-to-date, visible to the reviewer and functional.」 | 本文で確認 | 【AP1】 |
| 通知の URL | 本番の URL は必須、Sandbox の URL は任意。「You may use the same URL for both the production and the sandbox environments.」。送り元の IP は本番も Sandbox も 17.0.0.0/8 | 本文で確認 | Enabling App Store Server Notifications【AP10】 |
| Sandbox の通知が届く条件 | 「You receive notifications in the sandbox environment when you opt in to receive notifications in the sandbox environment and test your app in the sandbox environment. TestFlight also uses the sandbox environment to send notifications.」 | 本文で確認 | environment（App Store Server Notifications）【AP10】 |
| 見分け方 | 通知の `data.environment` が `Sandbox` か `Production`。Sandbox では `appAppleId` が無い | 本文で確認 | data、environment【AP10】 |
| App Store Server API | Sandbox の取引は Sandbox の base URL で引く。環境がわからなければ本番で引き、`4040010`（TransactionIdNotFoundError）なら Sandbox で引き直す | 本文で確認 | App Store Server API【AP11】 |

**nu-tori への当てはめ（本文からの読み取り）**: 審査は Sandbox の購入で課金を確かめる、と読める（旧い文書だが「in review by App Review」と名指ししている）。審査のアプリは本番のサーバーにつながる（`AGENTS.md` の「TestFlight と App Store の版は本番に」）。本番のサーバーが Sandbox の取引（アプリから送られた署名済みの取引、通知、API の問い合わせ）を受け付けないと、審査で「買ったのに開かない」になる。本番のサーバーは、`environment` が `Sandbox` の取引も検証して受け付け、Sandbox の通知の URL も設定しておく必要がある。ただし本番の DB で、Sandbox の購入で一般のアカウントがサブスク中にならないよう扱いを決める必要がある（Sandbox の購入はお金が動かない。審査用・TestFlight の人のアカウントだけがこれで開く）。どこまで受け付けるかの決め方は、この調査の範囲の外。

## 問い6: 購読のファミリー共有は戻せないか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 戻せるか | **戻せない**。「Keep in mind that once you turn on Family Sharing for an In-App Purchases in App Store Connect, you can't turn it off.」。subscriptions ページも「You can enable Family Sharing for your subscription in App Store Connect. Please note that this can't be undone.」 | 本文で確認 | App Store Connect ヘルプ「Turn on Family Sharing for In-App Purchases」【AP6】、【AP4】 |
| 単位 | 商品（サブスクの商品）ごとにオンにする | 本文で確認 | 同【AP6】 |
| 人数 | 購入者を含めて最大6人（「shared by up to six family members」。subscriptions ページは「up to five family members」で、購入者のほかに5人） | 本文で確認 | 【AP6】【AP4】 |
| 既存の加入者 | 新しい購入は、購入者の設定しだいで既定で共有される。オンにする前からの加入者は、サブスクの管理の画面で自分で共有を選ぶ | 本文で確認 | 【AP6】 |
| 利用者の側 | 「Users have the option of turning off Family Sharing in their subscription settings at any time.」 | 本文で確認 | 【AP6】 |
| 複数席の購入（multiseat）との関係 | 2026-09-14 から新しいサブスクは multiseat が既定でオン。両方オンなら、ファミリー共有は購入者の分だけ | 本文で確認 | App Store Connect ヘルプ「Manage purchase options」【AP6】 |

**関連して見つけたこと**: DPLA は「End-User」に Family Sharing で購入者に紐づく人を含め、Group Purchase の返金の扱いを定めている（Schedule 2 の 1.1(b)、3.8(c)）【AP2】。ファミリー共有の人は購入者とは別の Apple アカウントなので、サーバーで「誰がサブスク中か」を決めるときに、取引の `ownershipType`（購入者か家族か）を扱う必要が出る（subscriptions ページが `ownershipType` に触れている。本文で確認【AP4】）。

## 問い7: 1つのサブスクグループに価格の違う商品を並べ、ユーザーごとに見せ分けてよいか

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 価格の出し分け・A/B テストを明示的に許す・禁じる記述 | 見つからなかった | 本文を探したが記述なし（App Review Guidelines 全文、DPLA Schedule 2、subscriptions ページ、HIG、App Store Connect ヘルプのサブスクのページ） | 【AP1】【AP2】【AP4】【AP5】【AP6】 |
| グループに複数の商品を置くこと | 「Each level can have multiple subscription products, offering multiple durations and prices for people to choose from.」。グループに最大100商品。同じレベルに「equal content but different durations and other similar variables」を並べられる | 本文で確認 | App Store Connect ヘルプ「Offer auto-renewable subscriptions」【AP6】 |
| 同じものの別の形 | 3.1.2(b): 「Users should have a seamless upgrade/downgrade experience and should not be able to inadvertently subscribe to multiple variations of the same thing.」 | 本文で確認 | 【AP1】 |
| 値上げ・意図しない購入 | 5.6: 「Apps should never … trick them into making unwanted purchases, … raise prices in a tricky manner, … or engage in any other manipulative practices」 | 本文で確認 | 【AP1】 |
| 価格そのもの | 3.1 の前文: 「while pricing is up to you, we won't distribute apps and in-app purchase items that are clear rip-offs」 | 本文で確認 | 【AP1】 |
| 文言を試すこと | subscriptions ページは課金の促しについて「Test and measure the impact of these prompts, and consider trying different versions of your call-to-action messaging」と書く（価格ではなく文言の話） | 本文で確認 | 【AP4】 |
| 商品はどこに見えるか | 「This information displays in the Apple In-App Purchases section of your app's product page on the App Store.」。加入者の管理の画面は「The sheet displays the customer's currently active subscription for your app and the options to view, upgrade, downgrade, or cancel their subscription.」 | 本文で確認 | 【AP4】、showManageSubscriptions(in:)【AP14】 |
| 審査に出す商品 | 2.1(b): 設定した商品が審査でアプリ内に見つからないなら、その理由を審査メモに書く（「If any configured in-app purchase items cannot be found or reviewed in your app, explain the reason in your review notes.」） | 本文で確認 | 【AP1】 |

**nu-tori への当てはめ（本文からの読み取り）**:
- 価格の違う商品を同じグループに置くこと自体は、App Store Connect の作りが想定している（同じレベルに複数の価格）。それをユーザーごとに出し分けることを禁じる文言は見つからない。
- ただし出し分けた商品は、App Store の商品ページのアプリ内課金の欄に載りうるし、加入者はサブスクの管理の画面で同じグループの別の商品に乗り換えられる（安い方が見えて移れる）。「見せない」ことは保証できないので、出し分けは「アプリ内の課金画面でどれを勧めるか」にとどまる、と考えておく。
- 見つけた側から「同じ内容なのに人によって値段が違う」と受け取られると、5.6 の「manipulative practices」や 3.1.2(a) の bait-and-switch の議論になりうる。商品ごとに表示名と説明を分け、どの商品も課金画面に出したときに価格・期間・内容が正しく書かれているようにしておくのが無難。審査に出す商品のうち審査の人に見えないものは、2.1(b) に従って理由を審査メモに書く。
- Apple 自身の価格の A/B テストの機能（App Store Connect の中のもの）は、今回読んだ App Store Connect ヘルプのサブスクのページの目次には見当たらなかった（商品ページの A/B テスト「Product Page Optimization」はある）。

## 追記: App Store の署名つきの値（2026-10-21）

仕様 #647 の「App Store の署名」を実装するときに読んだ（#668）。読み方は冒頭の「確認の方法と限界」と同じ。

**使う項目**（本文で確認【AP16】【AP17】。時刻はどれも UNIX 時刻のミリ秒）:
- 通知の本文: `notificationUUID`（重複を見分けて捨てるための ID）、`notificationType`、`subtype`（特定の種類にだけある）、`signedDate`（App Store が署名した時刻。「This timestamp remains the same if the system resends the notification during a retry.」）、`data`（`bundleId`・`environment`・`signedTransactionInfo`・`signedRenewalInfo` を持つ。`data`・`appData`・`summary`・`externalPurchaseToken` はどれか1つだけ）
- 取引: `transactionId`・`originalTransactionId`・`productId`・`purchaseDate`・`expiresDate`・`appAccountToken`・`revocationDate`・`environment`・`transactionReason`（`PURCHASE` か `RENEWAL`）・`bundleId`。`appAccountToken` は、アプリが購入のときに渡したときだけ返る（「you can optionally generate an app account token」）
- 更新の情報: `gracePeriodExpiresDate`
- 署名の鎖: どの値も JWS で、ヘッダの `x5c` に鎖が載る【AP17】。Apple のサーバーのライブラリは、`x5c` が3つであること、中間の証明書が差し込んだ根で署名されていること、署名の証明書が中間で署名されていること、中間が CA であること、中間の印（OID 1.2.840.113635.100.6.2.1）と署名の証明書の印（OID 1.2.840.113635.100.6.11.1）を確かめ、オンラインの確かめをしないときは値の `signedDate` の時点で3つの証明書の有効期限を見る【AP19】。根は Apple Root CA - G3 で、SHA-256 の指紋は `63 34 3A BF B8 9A 6A 03 EB B5 7E 9B 3F 5F A7 BE 7C 4F 5C 75 6F 30 17 B3 A8 C4 88 C3 65 3E 91 79`【AP20】

**送り直しの決まり**（本文で確認【AP15】）: 「Send HTTP 200, or any HTTP code between 200 and 206, if the post was successful.」。成功を受け取れなければ、V2 の通知は「at 1, 12, 24, 48, and 72 hours after the previous attempt」に5回送り直す。「Retry notifications are available only in the production environment. In the sandbox environment, the App Store server attempts to send the notification one time.」

**環境の値**: 文書の `environment` は `Sandbox` と `Production` だけを挙げる（本文で確認【AP16】【AP17】）。Xcode の StoreKit のテストの取引は、StoreKit の文書に `xcode` の環境としてある【AP18】。Apple のサーバーのライブラリは `Xcode` と `LocalTesting` も環境の値に持ち、この2つは App Store が署名しないので鎖を確かめないと書く【AP19】（文書の本文には `LocalTesting` の記述なし）。

**`REFUND_REVERSED` の取引の `revocationDate`**: 本文を探したが記述なし。`notificationType` の `REFUND_REVERSED` は「If your app revoked content or services as a result of the related refund, it needs to reinstate them.」と書くだけで、`revocationDate` は「The UNIX time, in milliseconds, that the App Store refunded the transaction or revoked it from Family Sharing.」とだけある【AP10】【AP17】。戻したあとの取引に `revocationDate` が残るかは分からない。

## 関連して見つけたこと

- **日本の消費税**: 日本に住む開発者の日本向けの販売では、消費税の申告と納付は開発者の責任で、iTunes KK の手数料には消費税が含まれる（DPLA Exhibit B 6(A)、本文で確認【AP2】）。
- **値上げ**: 既存の加入者は値上げの通知か同意の求めを受け、同意しないと期間の終わりで切れる（`EXPIRED` + `PRICE_INCREASE`）。既存の加入者の価格を据え置いたまま新規だけ値上げできる（App Store Connect ヘルプ「Manage pricing」、subscriptions ページ、本文で確認【AP6】【AP4】）。値下げは既存の加入者にも自動で当たり、高い価格を据え置く選択肢はない。
- **サブスクの終了**: サブスクを売るのをやめるときは、売るのをやめてからサービスを止めるまで最低31日要る（App Store Connect ヘルプ「Set availability」、本文で確認【AP6】）。
- **有料の日数**: 1年分の有料の日数がたまると Apple の手数料が下がる。無料体験（Apple のもの）と更新日の延長は日数に含まれない。60日のうちに戻れば日数が続く（subscriptions ページ、本文で確認【AP4】）。サーバーが数える無料体験は Apple の側では何も起きていないので、日数にも関係しない（本文からの読み取り）。

## 確かめられなかったこと

- 消費者庁の文書の中で、App Store のアプリ内課金（Apple が代理人のプラットフォーム）に特定商取引法の表示をどこに置けばよいかを名指しした記述。特定商取引法 26 条（適用除外）の本文は読んでいない。
- App Store の購入のシートが法 12 条の 6 の「特定申込み」の画面に当たるか。
- Apple の標準 EULA へのリンクで、DPLA 3.8(b) と subscriptions ページの「Terms of Use へのリンク」の要件を満たすか。
- サーバーが数える無料体験（Introductory Offer を使わない）を、審査がどう見るか。許す・禁じる記述はどちらも見つからなかった。
- App Review が Sandbox で購入することを、StoreKit 2 / App Store Server Notifications V2 の文書で書いた記述（旧い `verifyReceipt` の文書にだけある）。
- 1つのグループで価格を出し分けることへの App Review の扱い（明文なし）。Apple の価格の A/B テストの機能があるか。

## 出典一覧

### 日本
- J1: 特定商取引に関する法律（昭和51年法律第57号。令和8年法律第64号による改正、2026-08-12 施行の版。2 条、11 条、12 条、12 条の 6） — https://laws.e-gov.go.jp/law/351AC0000000057 （本文は e-Gov 法令 API v2 `https://laws.e-gov.go.jp/api/2/law_data/351AC0000000057`）
- J2: 特定商取引に関する法律施行規則（令和8年内閣府・経済産業省令第2号による改正、2026-05-21 施行の版。23 条、24 条、25 条） — https://laws.e-gov.go.jp/law/351M50000400089 （本文は e-Gov 法令 API v2）
- J3: 消費者庁 特定商取引法ガイド「通信販売広告Q＆A」（A1、A3、A15〜A21） — https://www.no-trouble.caa.go.jp/qa/advertising.html
- J4: 消費者庁 特定商取引法ガイド「通信販売」（広告の表示事項、表示事項を省略できる場合の表） — https://www.no-trouble.caa.go.jp/what/mailorder/
- J5: 消費者庁「通信販売の申込み段階における表示についてのガイドライン」 — https://www.no-trouble.caa.go.jp/pdf/20230421la02_09.pdf

### Apple
- AP1: App Review Guidelines（Last Updated: October 16, 2026。2.1、3.1、3.1.1、3.1.2、5.1.1(v)、5.6） — https://developer.apple.com/app-store/review/guidelines/
- AP2: Apple Developer Program License Agreement（Schedule 2 は October 13, 2026 版。Schedule 2 の 1.1、3.8、4.2、Exhibit A、Exhibit B 6(A)） — https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- AP3: App Store Connect ヘルプ（目次） — https://developer.apple.com/help/app-store-connect/
- AP4: Auto-renewable subscriptions（App Store） — https://developer.apple.com/app-store/subscriptions/
- AP5: Human Interface Guidelines「Apple In-App Purchase」（2026-09-17 更新）と「Managing accounts」 — https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase 、https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- AP6: App Store Connect ヘルプ
  - Enable billing grace period for auto-renewable subscriptions — https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions
  - Offer auto-renewable subscriptions — https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions
  - Manage pricing for auto-renewable subscriptions — https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions
  - Manage purchase options for an auto-renewable subscription — https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-purchase-options-for-auto-renewable-subscriptions
  - Set availability for an auto-renewable subscription — https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-availability-for-an-auto-renewable-subscription
  - Turn on Family Sharing for In-App Purchases — https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases
  - Provide a custom license agreement — https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement
  - App information（参照） — https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
  - Testing subscriptions and In-App Purchases in TestFlight — https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight
  - Overview of testing in sandbox — https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox
- AP7: Offering account deletion in your app（5.1.1(v)） — https://developer.apple.com/support/offering-account-deletion-in-your-app/
- AP8: Apple Media Services 利用規約（日本、最終更新日 2026年9月14日） — https://www.apple.com/jp/legal/internet-services/itunes/jp/terms.html
- AP9: Reducing involuntary subscriber churn — https://developer.apple.com/documentation/storekit/reducing-involuntary-subscriber-churn
- AP10: App Store Server Notifications — notificationType https://developer.apple.com/documentation/appstoreservernotifications/notificationtype 、Enabling App Store Server Notifications https://developer.apple.com/documentation/appstoreservernotifications/enabling-app-store-server-notifications 、environment https://developer.apple.com/documentation/appstoreservernotifications/environment 、data https://developer.apple.com/documentation/appstoreservernotifications/data
- AP11: App Store Server API — https://developer.apple.com/documentation/appstoreserverapi
- AP12: Testing at all stages of development with Xcode and the sandbox — https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox
- AP13: Validating receipts with the App Store（`verifyReceipt` は非推奨） — https://developer.apple.com/documentation/storekit/validating-receipts-with-the-app-store
- AP14: showManageSubscriptions(in:) — https://developer.apple.com/documentation/storekit/appstore/showmanagesubscriptions(in:)
- AP15: Responding to App Store Server Notifications — https://developer.apple.com/documentation/appstoreservernotifications/responding-to-app-store-server-notifications
- AP16: 通知の本文の項目 — responseBodyV2DecodedPayload https://developer.apple.com/documentation/appstoreservernotifications/responsebodyv2decodedpayload 、notificationUUID https://developer.apple.com/documentation/appstoreservernotifications/notificationuuid 、signedDate https://developer.apple.com/documentation/appstoreservernotifications/signeddate
- AP17: 取引と更新の情報の項目 — JWSTransactionDecodedPayload https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload 、JWSRenewalInfoDecodedPayload https://developer.apple.com/documentation/appstoreserverapi/jwsrenewalinfodecodedpayload 、appAccountToken https://developer.apple.com/documentation/appstoreserverapi/appaccounttoken 、revocationDate https://developer.apple.com/documentation/appstoreserverapi/revocationdate 、transactionReason https://developer.apple.com/documentation/appstoreserverapi/transactionreason 、gracePeriodExpiresDate https://developer.apple.com/documentation/appstoreserverapi/graceperiodexpiresdate 、environment https://developer.apple.com/documentation/appstoreserverapi/environment 、JWSDecodedHeader https://developer.apple.com/documentation/appstoreserverapi/jwsdecodedheader
- AP18: StoreKit の AppStore.Environment.xcode — https://developer.apple.com/documentation/storekit/appstore/environment/xcode
- AP19: Apple の app-store-server-library（Node）の `models/Environment.ts` と `jws_verification.ts` — https://github.com/apple/app-store-server-library-node
- AP20: Apple PKI（Apple Root CA - G3 の証明書と指紋） — https://www.apple.com/certificateauthority/
