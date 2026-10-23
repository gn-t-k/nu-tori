# 常駐型の AI エージェント3つ（Claude Duet・OpenAI dots・Grok Bot）を、事業の仕事に割り当てられるか

調査日: 2026-10-23
対象: 2026年の秋に出た「自分のクラウドのコンピューターで動き続ける」エージェント3つ。Anthropic の **Claude Duet**、OpenAI の **dots**（ChatGPT の中の機能）、xAI の **Grok Bot**。nu-tori（個人開発の公開 iOS アプリ）の事業の仕事（宣伝、問い合わせとユーザーの声の収集、予算と数字）を任せる前提で、できること、動く場所、常時動くか、つなげる先、承認の仕組み、料金、提供の状況を調べた。

> **確認の方法と限界**
> - **この調査では、公式ページの本文を直接開けなかった。** この環境の通信の出口が claude.com、support.claude.com、code.claude.com、anthropic.com、openai.com、help.openai.com、learn.chatgpt.com、x.ai、docs.x.ai、x.com への接続を拒んだ（プロキシの 403）。WebFetch も名前解決に失敗した。
> - そのため、**Web 検索の道具を公式のドメインだけに絞って（`allowed_domains`）検索し、検索結果に出る公式ページの抜粋と要約を読んだ**。抜粋は検索の道具が本文から抜き出したもので、英語の原文がそのまま出ているものと、言い換えられたものが混ざる。言い換えの誤りや、古い版の抜粋を読んでいる恐れがある。
> - そこで、`agent-ios-verification.md` の3つの区分を、この調査では次の意味で使う。
>   - 「**抜粋で確認**」: 公式ページの抜粋に、その主張がそのまま出ていた。原文に見える英語を短く添える（検索の道具が言い換えた可能性は残る）。
>   - 「**抜粋からの読み取り**」: 抜粋の記述から推し量った。何から読み取ったかを添える。
>   - 「**探したが記述なし**」: 公式ドメインに絞って検索したが、抜粋に出なかった。本文に書いてある可能性は残る。
>   - 頼まれた「本文で確認」は、本文を読んでいないので使わない。**確かさは全体として「中」**と見てほしい。実際に申し込む前に、出典の URL を自分のブラウザで開いて確かめる。
> - 公式の X アカウント（@claudeai、@OpenAI、@xai）の投稿は、x.com に届かず、検索にも出なかったので読んでいない。
> - 二次情報（ニュース、第三者のブログ）は検索結果に多く出たが、使っていない。食い違いの指摘として1か所だけ触れる（そう明記する）。
> - 3つとも出たばかりで、提供の範囲や料金が数週間ごとに変わっている。2026-10-23 時点の状態として読む。

## 結論の要約

- **名前の対応**: 3つとも、依頼にあった名前のとおりの公式製品が見つかった。Claude Duet は claude.com/product/claude-duet、dots は openai.com/index/introducing-dots/、Grok Bot は x.ai/bot。Grok Bot は「複数の Bot」を作って渡し合える製品で、依頼の「Grok Bots」はこれと判断した（抜粋で確認）。
- **3つとも「自分専用のクラウドのコンピューター＋ブラウザ」で動き、手元の端末を閉じても働き続ける**（抜粋で確認）。話しかける場所が違う。
  - Claude Duet: 専用アプリ（iOS・Android）と claude.ai の Web
  - dots: ChatGPT（デスクトップ・Web・モバイル）、Slack、Microsoft Teams、音声通話
  - Grok Bot: デスクトップ（macOS）と iOS のアプリ、X で `@bot` を付けて投稿
- **日本から今すぐ使えそうなのは Grok Bot と dots。Claude Duet は米国の Pro・Max だけで、順番待ち（waitlist）**（抜粋で確認）。dots は「対象の市場」の Pro と Business Premium に順に出している。除かれる地域に EEA・スイス・英国が書かれているが、日本が対象かは抜粋に無かった（探したが記述なし）。Grok Bot の X からの呼び出しは、オーストラリア・英国・EU などで使えないが、日本は除外の一覧に無い（抜粋からの読み取り）。
- **予定とできごとで動けるか**
  - Grok Bot: **できる**。「ルーティン」で時刻の予定と、対応するアプリのできごと（Slack のスレッド、GitHub の PR など）で動く（抜粋で確認）。
  - dots: **できる**。繰り返しのタスクと、対応するアプリのできごと（例: Slack のチャンネルに新しいバグ報告）で動く（抜粋で確認）。
  - Claude Duet: 朝のまとめ（morning brief）と、決まった間隔の見回りはある。自分で予定を組む機能と、できごとで動く機能は抜粋に無かった（探したが記述なし）。見回りの合間に来た急ぎのものは見逃しうる、と公式が書いている（抜粋で確認）。
- **外へ向く操作の承認**
  - Claude Duet: メッセージの送信、支払い、署名、削除の前に、何をするかを見せて承認を待つ作り（抜粋で確認）。承認を外す設定があるかは、抜粋に無かった（探したが記述なし）。
  - dots: 操作ごとに「聞かずにやる／頼まれたときだけ／先に聞く／人に渡す」を選べる（Custom rules）。下書きを頼んでも送信の許可にはならない。メール送信の前に自動の確認（Auto-review）が入り、これは外せない（抜粋で確認）。**「聞かずにやる」も選べるので、設定を誤らないことが要る。**
  - Grok Bot: 「Ask first（先に聞く）」の規則を作れ、規則がぶつかると Ask first が勝つ。送信・投稿・購入・削除のような取り消せない操作の前に承認を求める。ユーザー不在で始まった仕事（ルーティンなど）の承認は約10分で期限切れになり、実行されない（抜粋で確認）。**全部の Bot が1台のコンピューターと全部のログインを共有する**ので、Bot を分けても権限は分けられない（抜粋で確認）。
- **料金**（追加料金ではなく、プランに含まれる）
  - Claude Duet: プレビュー中は Pro（月20ドル）と Max（月100ドル・200ドル）に追加料金なしで含まれる。チャットと同じ利用の上限を使い、裏の見回りも上限を減らす（抜粋で確認）。
  - dots: Pro（月100ドル・200ドル・500ドル）の機能。dot との会話は上限に数えないが、dot が始めた Codex・ChatGPT Work のタスクは数える（抜粋で確認）。Plus には無い（抜粋で確認）。
  - Grok Bot: The X Subscription の Premium（月30ドル）・Super（月100ドル）・Ultra（月200ドル）に含まれ、Plus には含まれない。旧 SuperGrok と Cursor の各プランにも含まれる（抜粋で確認。価格のページどうしで食い違いがある）。
- **nu-tori の「ユーザーの声を集める」役には、今の時点では Grok Bot か dots が当てはまる。** どちらも予定とできごとで動き、Gmail・Slack・GitHub につなげ、自作の MCP サーバーもつなげる（抜粋で確認・抜粋からの読み取り）。Claude Duet は日本から使えないうえ、GitHub と自作のつなぎ先が確かめられなかった。詳細は末尾の「nu-tori の役割への当てはめ」。

## 3つの形の違い（図）

```mermaid
flowchart LR
  subgraph 話しかける場所
    A1[Duet 専用アプリ<br/>iOS・Android・claude.ai]
    B1[ChatGPT・Slack・Teams・通話]
    C1[Grok Bot アプリ<br/>macOS・iOS・X の @bot]
  end
  subgraph クラウドのコンピューター
    A2[Duet: 自分のクラウドのコンピューターとブラウザ]
    B2[dot: 自分のクラウドのコンピューターとブラウザ<br/>手元の PC は任意でつなぐ]
    C2[ユーザーごとに1台の microVM<br/>全部の Bot が共有]
  end
  A1 --> A2
  B1 --> B2
  C1 --> C2
  A2 -->|朝のまとめ・一定間隔の見回り| A3[つなぎ先: Gmail・カレンダー・Drive・Slack など]
  B2 -->|繰り返しのタスク・できごと| B3[つなぎ先: プラグイン（Gmail・Slack・GitHub・自作 MCP）]
  C2 -->|ルーティン: 予定・できごと| C3[つなぎ先: プラグイン（Gmail・GitHub・X・自作 MCP）]
```

```mermaid
flowchart TB
  Q[外へ向く操作<br/>メール送信・投稿など] --> D{どのサービス}
  D -->|Duet| D1[必ず内容を見せて承認待ち<br/>外す設定は見つからず]
  D -->|dots| D2[Custom rules で操作ごとに選ぶ<br/>先に聞く を選べば承認待ち<br/>メールは自動の確認が必ず入る]
  D -->|Grok Bot| D3[Ask first の規則を作る<br/>取り消せない操作は承認待ち<br/>不在時の承認は約10分で失効]
```

## 1. Claude Duet（Anthropic）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 名前の対応 | 依頼の名前のとおり「Claude Duet」という製品がある | 抜粋で確認 | https://claude.com/product/claude-duet |
| 何か | Claude が「先回りするエージェント」として働く新しいアプリ。メッセージで頼むと、クラウドで自分で働き、必要なときだけ声をかけ、仕上がったものを返す（"a proactive agent that understands what needs your attention. It takes on tasks of all sizes, keeps working while you're away, and waits for your ok when it matters."） | 抜粋で確認 | https://claude.com/product/claude-duet 、https://claude.com/resources/articles/claude-duet |
| 公開日 | 2026-10-21 にリサーチプレビューを開いた（"We just opened a research preview for users on Pro and Max plans: Claude Duet"） | 抜粋で確認 | https://claude.com/resources/articles/claude-duet 、https://support.claude.com/en/articles/12138966-release-notes |
| できること | 毎朝、つないだメールとカレンダーを見て、一番大事なものを選んだまとめ（morning brief）を送り、返信の下書きなど最初の一歩を始める。読む、下書きする、準備するは自分で行う | 抜粋で確認 | https://support.claude.com/en/articles/17631495-get-started-with-claude-duet |
| 動く場所 | クラウドの自分のコンピューターで動き、アプリを閉じても働き続ける。つなぎ先の無いサイトには、クラウドの自分のブラウザを使う。ブラウザで働く様子を見ることも、ブラウザを代わりに操作することもできない | 抜粋で確認 | 同上 |
| 使う端末 | iOS と Android の専用アプリ。PC では claude.ai の Web で開く（"Claude Duet is a standalone app for iOS and Android. On a computer, you can open it on the web at claude.ai."） | 抜粋で確認 | 同上 |
| モデル | Claude Opus 5.5 で動き、モデルは選べない（"You can't choose a model."） | 抜粋で確認 | 同上 |
| 常時動くか・予定 | 決まった間隔でアカウントを見回る（"It checks your accounts at set intervals, so something urgent can arrive between checks."）。朝のまとめがある | 抜粋で確認 | 同上 |
| 自分で予定を組む・できごとで動く | 「毎週月曜に〜」のような予定の作成や、メールの着信のようなできごとで動く機能の記述は出なかった（Anthropic の別製品の Cowork と Claude Code には予定の機能がある） | 探したが記述なし（claude.com・support.claude.com で "Claude Duet" と schedule・trigger・recurring を検索） | — |
| つなぎ先 | Claude にすでに設定したつなぎ先（コネクタ）を使う。挙がっているのは Gmail、Google Calendar、Google Drive、Slack、QuickBooks、HubSpot、Docusign、Calendly。製品ページは Notion、Stripe、Shopify も挙げ、「6,000 以上のコネクタとプラグイン」と書く。Slack などは Duet の中では機能が限られ、Microsoft 365 はまだ使えない | 抜粋で確認 | https://support.claude.com/en/articles/17631495-get-started-with-claude-duet 、https://claude.com/product/claude-duet |
| GitHub・X・App Store Connect・自作の MCP | Duet のつなぎ先の一覧に GitHub と X は無かった。自作の MCP サーバー（カスタムコネクタ）が Duet で使えるかの記述も出なかった。Claude 本体では Pro・Max でカスタムコネクタを足せるが、Duet に引き継がれるかは不明 | 探したが記述なし（同上の検索、"Claude Duet" と MCP・custom connector・GitHub） | Claude 本体のカスタムコネクタ: https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp |
| Claude の他の作業 | Claude の中の作業は読めるが変えられない。PC のファイルや全部のプロジェクトは見えない | 抜粋で確認 | https://support.claude.com/en/articles/17631495-get-started-with-claude-duet |
| サイトへのログイン | 保存したログインはまだ使えない。1Password でのログインは「近日」。Claude はパスワードやトークンを直接見ない | 抜粋で確認 | 同上（検索の抜粋） |
| 支払い | Link by Stripe と Shop Pay を Duet の中でつなげる。買う前に毎回聞き、1回だけ使えるカード番号で払う。米国の支払い手段が要る | 抜粋で確認 | https://support.claude.com/en/articles/17666484-how-to-use-link-by-stripe-with-claude-duet 、https://support.claude.com/en/articles/17666489-how-to-use-shop-pay-with-claude-duet |
| 承認 | メッセージの送信、支払い、署名、削除の前に、何をするかを正確に見せて承認を待つ作り。つないだアカウントからのメール送信も承認のうえで行う。承認があっても、有価証券の売買、口座間の送金、他人のアカウントへのアクセスはしない | 抜粋で確認 | https://claude.com/product/claude-duet 、https://support.claude.com/en/articles/17631495-get-started-with-claude-duet |
| 承認を外せるか | 「承認なしで送る」設定があるかの記述は出なかった（Claude 本体の Google Workspace コネクタは、既定で送信の前に承認を求め、Team・Enterprise では管理者が「毎回聞かない」を許せる） | 探したが記述なし（Duet について） | Claude 本体: https://support.claude.com/en/articles/10166901-use-google-workspace-connectors |
| 料金 | プレビュー中は Pro と Max に追加料金なしで含まれる。チャットと同じ利用の上限（5時間ごとと週ごと）を使い、朝のまとめや見回りなどの裏の仕事も数える。参加した人には上限の全リセットが1回ある（2026-11-30 まで） | 抜粋で確認 | https://support.claude.com/en/articles/17631495-get-started-with-claude-duet |
| プランの価格 | Pro は月20ドル（年払いで月17ドル相当）。Max は 5x が月100ドル、20x が月200ドル | 抜粋で確認 | https://claude.com/pricing 、https://support.claude.com/en/articles/11049741-what-is-the-max-plan |
| 提供の状況 | 米国の Pro・Max の利用者に、順番待ちで少しずつ（"We're adding people gradually, and you'll get an email when it's your turn."）。Team・Enterprise にはまだ無い（後で出す予定） | 抜粋で確認 | https://claude.com/product/claude-duet 、https://support.claude.com/en/articles/17631495-get-started-with-claude-duet |
| 公式が書いている弱み | スレッドを読み違えたり、急ぎの度合いを見誤ったりしうる。見回りの合間に来たものを見逃しうる | 抜粋で確認 | https://claude.com/product/claude-duet |

## 2. OpenAI dots

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 名前の対応 | ChatGPT の機能「dots」（ひとつひとつを「dot」と呼ぶ）。依頼の名前と一致する | 抜粋で確認 | https://openai.com/index/introducing-dots/ 、https://chatgpt.com/features/dots/ |
| 公開日 | 2026-09-29 の DevDay で発表 | 抜粋で確認（発表の日付） | https://openai.com/index/introducing-dots/ 、https://openai.com/index/devday-2026-recap/ |
| 何か | GPT-6 Astra で動き、自分のクラウドのコンピューターを持ち、フィードバックから学び、24時間目標に向けて働く（"Dots are powered by GPT‑6 Astra, they have their own cloud computer, learn from feedback over time, and can work towards your goals 24/7."） | 抜粋で確認 | https://openai.com/index/introducing-dots/ |
| 動く場所 | クラウドの自分のコンピューターとブラウザ。手元の PC が切れていても働く。ブラウザのログインは自分のブラウザとは別。サイトがログインを求めると、会話の外で資格情報を渡す仕組みか、自分でブラウザを操作してログインする。クラウドのブラウザを拒むサイトでは、つないだ PC を使える | 抜粋で確認 | https://learn.chatgpt.com/docs/dots 、https://learn.chatgpt.com/docs/dots/computers-and-apps |
| 手元の PC | PC へのアクセスは任意で、既定では切れている。つなぐには、その PC で ChatGPT のデスクトップアプリを使う | 抜粋で確認 | https://learn.chatgpt.com/docs/dots/computers-and-apps |
| 話しかける場所 | ChatGPT（デスクトップ・Web・モバイル）、Slack と Microsoft Teams（DM、チャンネルでのメンション）、ChatGPT アプリからの音声通話。dot から電話はかけてこない。場所を替えても記憶は続く。SMS は「近日」 | 抜粋で確認 | https://learn.chatgpt.com/docs/dots/channels 、https://help.openai.com/en/articles/20001530-getting-started-with-your-dot |
| 仕事を渡す先 | 裏で別のエージェントを使い、クラウドの新しいスレッドを始め、つないだ PC で ChatGPT Work や Codex のタスクを作れる | 抜粋で確認 | https://learn.chatgpt.com/docs/dots |
| 予定 | 繰り返しのタスクを保存できる。何を確かめるか、いつ動くか（時間帯、終わりの日）、どんな変化で知らせるか、結果の送り先を決める。「Scheduled」の欄で管理する | 抜粋で確認 | https://learn.chatgpt.com/docs/dots/tasks-and-memory |
| できごとで動く | 元のアプリが対応していれば、「Slack のチャンネルに新しいバグ報告が来たら」のようなできごとで動ける | 抜粋で確認 | 同上 |
| 先回りの調べもの | 頼まれていないときも裏で役に立つことを探す（proactive research）。このときは**つないだアプリを読み取り専用でしか使えず**、送信、内容の変更、ブラウザや PC の操作はできない | 抜粋で確認 | 同上、https://help.openai.com/en/articles/20001529-dots-privacy-security-and-safety-faqs |
| つなぎ先 | 自分のアカウントで入れて有効にしたプラグイン（対応するもの）を、その接続と権限のまま使う。OpenAI のプラグインの一覧に Gmail、Slack、GitHub がある。Gmail のプラグインは検索、仕分け、返信の下書きができ、アーカイブ・ラベル・ゴミ箱は明示的に頼んだときだけ | 抜粋で確認 | https://learn.chatgpt.com/docs/dots 、https://developers.openai.com/codex/plugins |
| アプリの数 | 「4,000 以上のアプリ」とする検索の要約と、その数字は見当たらないとする要約があり、食い違った | 確かめられず | https://openai.com/index/introducing-dots/ |
| 自作の MCP | ChatGPT のプラグインの画面から自作の MCP サーバーを足せる（Developer Mode は不要）。リモートの MCP だけで、手元のサーバーはトンネルが要る。dot が「入れて有効にしたプラグイン」を使うことから、自作の MCP も dot で使えると読める | 抜粋で確認（ChatGPT 全体）／抜粋からの読み取り（dot で使えるか） | https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt |
| X・App Store Connect | X や App Store Connect の公式プラグインの記述は出なかった。ブラウザ経由か自作の MCP で届く可能性はあるが未確認 | 探したが記述なし（openai.com・help.openai.com・learn.chatgpt.com で X、App Store Connect を検索） | — |
| 承認（Custom rules） | 操作ごとに「聞かずにやる」「明示的に頼んだときだけ」「先に聞く」「その手順を人に渡す」を選べる。デスクトップと Web では Settings > Personalization > Custom rules | 抜粋で確認 | https://learn.chatgpt.com/docs/dots/controls |
| 承認（送信） | 下書きを頼んでも送信の許可にはならない。1回の承認は、その後も人に連絡してよい許可にはならない。メールを出す前に、宛先と本文を自動で確かめる（Auto-review）。Custom rules で必須の確認は外せない | 抜粋で確認 | https://help.openai.com/en/articles/20001530-getting-started-with-your-dot 、https://help.openai.com/en/articles/20001529-dots-privacy-security-and-safety-faqs |
| 承認（プラグインの権限） | プラグインごとに「毎回聞く／読み取りだけ／低リスクは許す／全部許す」を選べる。メールの送信は追加の確認が要りうる操作に挙がっている | 抜粋で確認 | https://help.openai.com/en/articles/20001495 |
| 料金 | Pro の機能（"Dot, your always-on agent"）。Pro は月100ドル・200ドル・500ドル。Plus には無い。dot との会話は利用の上限に数えないが、dot が Codex や ChatGPT Work で動かすタスクは数える。発表から1か月は、対象の Pro・Business・Enterprise で dots の利用をプランの枠に数えない | 抜粋で確認 | https://chatgpt.com/pricing/ 、https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers 、https://help.openai.com/en/articles/6825453-chatgpt-release-notes |
| Business Premium の価格 | Business には Standard と Premium の席があり、Premium は ChatGPT Work と Codex の枠が多い。席の価格は抜粋に出なかった | 探したが記述なし | https://help.openai.com/en/articles/12003714-chatgpt-business-models-and-limits |
| 提供の状況 | 対象の市場の 18 歳以上の Pro と Business Premium に順に出している。Pro は EEA・スイス・英国を除く。Enterprise（Edu、Healthcare を含む）はベータで、管理者が有効にする（既定は切）。日本が対象の市場かは抜粋に出なかった | 抜粋で確認／日本は探したが記述なし | https://openai.com/index/introducing-dots/ 、https://help.openai.com/en/articles/6825453-chatgpt-release-notes 、https://help.openai.com/en/articles/20001554-manage-dots-in-chatgpt-workspaces |
| 複数の dot | 今は主に1つの dot。「チームの dots」は今後の構想として書かれている | 抜粋で確認（構想として） | https://openai.com/index/introducing-dots/ |

## 3. Grok Bot（xAI）

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 名前の対応 | 製品名は単数の「Grok Bot」。ひとつのアカウントで複数の Bot を作り、渡し合わせる。依頼の「Grok Bots」はこれと判断した | 抜粋で確認 | https://x.ai/bot 、https://x.ai/news/introducing-grok-bot |
| 公開日 | 2026-08-11 にベータで公開。2026-08-26 に対象プランを広げ、2026-09-03 に Enterprise 向けを発表 | 抜粋で確認（後の発表とニュースの一覧の日付） | https://x.ai/news/grok-bot-more-plans 、https://x.ai/news/grok-bot-for-enterprise |
| 何か | 「仕事を終わらせる AI のチームメイト」。同僚のようにメッセージを送って仕事を渡す。チャットの下書きではなく、実際の道具の中で仕事を終える | 抜粋で確認 | https://x.ai/bot 、https://docs.x.ai/grok-bot/overview |
| 動く場所 | ブラウザ、ファイル、ターミナルのある、ずっと残るクラウドのコンピューターで動く。**ユーザーごとに1台の Firecracker microVM で、そのユーザーの全部の Bot が共有する**。ホストは Cursor のクラウド | 抜粋で確認 | https://docs.x.ai/grok-bot/overview 、https://docs.x.ai/grok-bot/teams-and-enterprises |
| 複数の Bot | ファイル、ブラウザのセッション、アプリのログインを共有するので、設定し直さずに仕事を渡せる。「chief of staff（まとめ役）」の Bot の下に、受信箱、経費、採用、バグ修正などの専門の Bot を置く形を勧めている。グループチャットに入れると、自分たちで仕事を渡し、担当を決め、判断が要るときだけ人を呼ぶ | 抜粋で確認 | https://x.ai/news/introducing-grok-bot 、https://x.ai/bot/guides/grok-bot-101 |
| Bot ごとの権限 | **Bot を分けても安全の境界にならない**（"The computer is assigned per user, not per Bot. Do not use separate Bots as a security boundary."） | 抜粋で確認 | https://docs.x.ai/grok-bot/teams-and-enterprises |
| 使う端末 | デスクトップ（macOS）と iOS | 抜粋で確認 | https://x.ai/news/introducing-grok-bot |
| 常時動くか | アプリ、ノート PC、スマホを閉じても、裏の仕事とルーティンは止まらない | 抜粋で確認 | https://docs.x.ai/grok-bot/skills-routines-and-automations |
| 予定・できごと | 「ルーティン」で、1つの Bot がいつ仕事をするかを決める。時刻の予定（時間帯つき、間隔は5分以上）と、対応していればできごと（Slack のスレッド、GitHub の PR を見張る、など）。1つの Bot に50本まで。チャットで頼むと Bot が作って次の実行時刻を見せる。一度手順を見せると「スキル」として保存し、予定で繰り返せる | 抜粋で確認 | 同上、https://x.ai/news/designing-grok-bot |
| X から呼ぶ | X の投稿か返信で `@bot` を付けると、その投稿をメインの Bot に仕事として渡す。`@bot` は X には短い確認だけを返す。Grok のアカウントに X のアカウントをつなぐ必要がある | 抜粋で確認 | https://docs.x.ai/grok-bot/tag-on-x 、https://x.ai/news/grok-bot-and-x |
| X を読む・書く | 公開の投稿、アカウント、トレンドは、ログインなしで読める（読み取り専用）。DM、ブックマーク、ホームのタイムラインなどは X のプラグインをつなぐ。プラグインで投稿までできるかは抜粋に出なかった | 抜粋で確認／投稿は探したが記述なし | https://docs.x.ai/grok-bot/computer-and-apps |
| つなぎ先 | Grok Bot に別のつなぎ先の一覧は無く、つなぎ先はアプリの中で「プラグイン」として出る。Grok のコネクタには Gmail と Google Calendar、Google Drive、OneDrive、Outlook、Teams、SharePoint、Salesforce、GitHub（リポジトリ、Issue、PR、コード）がある。Gmail は基本が読み取り専用で、書き込みと送信は段階的に有効にする | 抜粋で確認 | https://docs.x.ai/grok-bot/teams-and-enterprises 、https://docs.x.ai/grok/connectors 、https://docs.x.ai/grok/connectors/gmail-google-calendar |
| 自作の MCP | 一覧に無いサービスは、自分の MCP サーバーをつなげる（公開のインターネットから届く必要がある）。Team の管理者は Cursor の MCP の方針で制御する | 抜粋で確認（Grok のコネクタとして）／Grok Bot で同じに使えるかは抜粋からの読み取り | https://docs.x.ai/grok/connectors |
| Slack | Slack のスレッドを見張るルーティンの例と、Slack の議論を読む例はある。Slack の専用コネクタの記述は出なかった | 抜粋で確認（例として）／専用コネクタは探したが記述なし | https://docs.x.ai/grok-bot/skills-routines-and-automations |
| App Store Connect | 記述は出なかった | 探したが記述なし（x.ai・docs.x.ai で App Store Connect を検索） | — |
| 承認（Auto Review） | 有効にすると、シェルのコマンド、プラグインの呼び出し、コンピューターの操作、自動化の書き込み、別のエージェントへの委任を、独立した審査のモデルが見て「通す／承認を求める／止める」を決める。記憶への書き込みと多くの設定変更は対象外 | 抜粋で確認 | https://docs.x.ai/grok-bot/approvals-security-and-privacy |
| 承認（規則） | Settings → General → Auto-review に「Ask first（必ず先に聞く）」と「Allow automatically（審査が止めなければ通す）」の規則を作る。両方が当たると Ask first が勝つ。例に「外部へのメールは必ず承認」がある。承認のカードは Allow once・Always allow（規則を保存）・Deny | 抜粋で確認 | 同上 |
| 承認（取り消せない操作） | 送信、投稿、購入、削除のような取り消せない操作の前に、ユーザーのメッセージで承認を確かめる。送るメールは下書きのカードで承認を待つ | 抜粋で確認 | https://x.ai/changelog/bot |
| 承認（不在のとき） | ルーティンやできごとで始まった仕事の承認は、約10分で期限切れになり、その操作は実行されない | 抜粋で確認 | https://docs.x.ai/grok-bot/approvals-security-and-privacy |
| 承認の限界 | 承認と自動の審査は補助で、意図しない操作を全部は防げず、終わった操作は戻さない（利用規約）。読んだ Web ページやプラグインの結果が Bot を操ろうとしうる。パスワード、2段階認証、CAPTCHA、支払いの確認は人に渡す | 抜粋で確認 | https://x.ai/legal/grok-bot-terms 、https://docs.x.ai/grok-bot/computer-and-apps |
| 料金 | 最新の The X Subscription（2026年10月中旬の発表と読める）では Premium（月30ドル）・Super（月100ドル）・Ultra（月200ドル）に含まれ、Plus には含まれない。Bot の利用はその席の週ごとの共通の枠から使う。従量の追加もできる。旧来の SuperGrok と Cursor の Pro・Teams にも含まれる | 抜粋で確認 | https://x.ai/news/x-subscription 、https://docs.x.ai/x-subscription/grok-bot 、https://docs.x.ai/grok-bot/faq 、https://x.ai/news/grok-bot-more-plans |
| 料金の食い違い | x.ai/pricing の抜粋は SuperGrok 月30ドル・SuperGrok Plus 月100ドル、The X Subscription は Plus 月8ドル・Premium 月30ドル。SuperGrok Heavy の価格は出なかった。公開時の対象を「SuperGrok Heavy などに限る」とする抜粋と「全 SuperGrok」とする抜粋もあり、時期で変わったと読める | 抜粋どうしが食い違う | https://x.ai/pricing 、https://x.ai/news/x-subscription |
| 提供の状況 | ベータ。Enterprise は当初順番待ちで、その後提供を広げた。`@bot` の X からの呼び出しは、オーストラリア、英国、EU、アイスランド、リヒテンシュタイン、ノルウェーの X アカウントでは使えない（X に登録した国で判断）。日本は除外の一覧に無い | 抜粋で確認／日本は抜粋からの読み取り | https://docs.x.ai/grok-bot/tag-on-x 、https://x.ai/changelog/bot |

## nu-tori の役割への当てはめ

前提: 開発者は1人。アプリは公開の iOS アプリで、30日の無料体験つきのサブスク。使っている道具は GitHub、PostHog、App Store Connect、Sentry、Cloudflare。**外へ向く操作は全部、開発者の承認を通す**。最初のエージェントは「ユーザーの声を集める」役で、まとめには必ず原文を添える。人の声は TestFlight のフィードバックと問い合わせで受ける（`AGENTS.md`）。

以下は、上で確かめた範囲だけからの読み取り。

```mermaid
flowchart TB
  subgraph 声を集める役に要るもの
    R1[予定で毎日・毎週動く]
    R2[問い合わせのメールを読む]
    R3[GitHub の Issue に原文つきで書く<br/>または下書きを出す]
    R4[外へ出す操作は承認待ちにできる]
    R5[日本から使える]
  end
  G[Grok Bot] -->|ルーティン・Gmail・GitHub・自作 MCP・Ask first| OK1[全部に当てはまる<br/>ただし Gmail の送信と X 投稿は段階的に有効化]
  O[dots] -->|繰り返しタスク・Gmail・GitHub・自作 MCP・Custom rules| OK2[当てはまる<br/>ただし Pro 月100ドルから・日本が対象かは未確認]
  C[Claude Duet] -->|日本から使えない・GitHub と予定の機能が未確認| NG[今は当てはまらない]
```

- **ユーザーの声を集める役（最初の役）**
  - **Grok Bot が一番当てはまる。** ルーティンで毎日動き、Gmail（基本は読み取り専用）と GitHub につなぎ、外部へのメールを「Ask first」にできる。X の公開の投稿をログインなしで読めるので、「nu-tori」への言及を拾うのにも使える（抜粋で確認）。月30ドルの Premium から使える。
  - 気をつけること: 全部の Bot が1台のコンピューターとログインを共有するので、後で宣伝の Bot を足すと、声を集める Bot にも X や Gmail の書き込みのログインが見える。**規則（Ask first）で縛るのが頼りで、Bot を分けても権限は分かれない**。不在時に始まった承認は約10分で失効するので、承認待ちの操作は「次の自分の時間に下書きを見る」流れにしたほうがよい（抜粋からの読み取り）。
  - **dots も当てはまる**が、Pro が月100ドルからで、日本が対象の市場か確かめられなかった。先回りの調べものが読み取り専用に固定されている点は、声を集める役と相性がよい（抜粋からの読み取り）。Custom rules の既定が何かは抜粋に出なかったので、使い始めに送信と投稿を「先に聞く」に揃える。
  - **Claude Duet は今は使えない**（米国の Pro・Max の順番待ちだけ）。承認を外す設定が見つからず「送信の前に必ず見せる」作りなので、承認の原則とは一番合う。日本に来たら見直す価値がある（抜粋からの読み取り）。
- **宣伝の役**: X の言及を読むところまでは Grok Bot が強い（X の公開の投稿をログインなしで読める、`@bot` で投稿から仕事を渡せる）。X への投稿が承認のうえでできるかは確かめられなかった。dots と Duet に X のつなぎ先の記述は無かった。
- **予算と数字の役**: 3つとも、PostHog、App Store Connect、Sentry、Cloudflare の公式のつなぎ先の記述は出なかった。dots と Grok Bot は自作の MCP をつなげるので、読み取りだけの MCP を自分で用意すれば届く（抜粋からの読み取り）。Duet は QuickBooks や Stripe の例があるが、これらは nu-tori では使っていない。
- **どれを使っても、まとめに原文を添える決まりは、指示（スキル・ルーティンの手順）で守らせる必要がある。** 3つとも「原文を添える」ような出力の形を保証する機能の記述は無かった（探したが記述なし）。

## 出典一覧

すべて 2026-10-23 に、公式ドメインに絞った Web 検索の抜粋で読んだ（本文は直接開けなかった）。

- Claude Duet
  - https://claude.com/product/claude-duet
  - https://claude.com/resources/articles/claude-duet
  - https://support.claude.com/en/articles/17631495-get-started-with-claude-duet
  - https://support.claude.com/en/articles/17666484-how-to-use-link-by-stripe-with-claude-duet
  - https://support.claude.com/en/articles/17666489-how-to-use-shop-pay-with-claude-duet
  - https://support.claude.com/en/articles/12138966-release-notes
  - https://claude.com/pricing 、https://support.claude.com/en/articles/11049741-what-is-the-max-plan
  - 参考（Claude 本体）: https://support.claude.com/en/articles/10166901-use-google-workspace-connectors 、https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp
- OpenAI dots
  - https://openai.com/index/introducing-dots/
  - https://chatgpt.com/features/dots/
  - https://learn.chatgpt.com/docs/dots
  - https://learn.chatgpt.com/docs/dots/computers-and-apps
  - https://learn.chatgpt.com/docs/dots/channels
  - https://learn.chatgpt.com/docs/dots/tasks-and-memory
  - https://learn.chatgpt.com/docs/dots/controls
  - https://help.openai.com/en/articles/20001530-getting-started-with-your-dot
  - https://help.openai.com/en/articles/20001529-dots-privacy-security-and-safety-faqs
  - https://help.openai.com/en/articles/20001554-manage-dots-in-chatgpt-workspaces
  - https://help.openai.com/en/articles/20001495
  - https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
  - https://help.openai.com/en/articles/6825453-chatgpt-release-notes
  - https://chatgpt.com/pricing/ 、https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers
  - https://developers.openai.com/codex/plugins
- Grok Bot
  - https://x.ai/bot
  - https://x.ai/news/introducing-grok-bot
  - https://x.ai/news/grok-bot-more-plans
  - https://x.ai/news/grok-bot-for-enterprise
  - https://x.ai/news/designing-grok-bot
  - https://x.ai/news/grok-bot-and-x
  - https://x.ai/news/x-subscription
  - https://x.ai/changelog/bot
  - https://x.ai/bot/guides/grok-bot-101
  - https://x.ai/legal/grok-bot-terms
  - https://docs.x.ai/grok-bot/overview
  - https://docs.x.ai/grok-bot/teams-and-enterprises
  - https://docs.x.ai/grok-bot/skills-routines-and-automations
  - https://docs.x.ai/grok-bot/approvals-security-and-privacy
  - https://docs.x.ai/grok-bot/computer-and-apps
  - https://docs.x.ai/grok-bot/tag-on-x
  - https://docs.x.ai/grok-bot/faq
  - https://docs.x.ai/x-subscription/grok-bot
  - https://docs.x.ai/grok/connectors 、https://docs.x.ai/grok/connectors/gmail-google-calendar
  - https://x.ai/pricing
