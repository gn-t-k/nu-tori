# 写真から料理と材料を推定する LLM の比較材料と費用

調査日: 2026-09-24
対象: Issue #23（wayfinder マップ #19 の子）。写真から「料理 → 材料 → 量」の構造（ADR-0005）で推定するために、クラウドの LLM（Claude・GPT・Gemini）と Apple の端末上モデルを比べる材料を一次情報で集める。

> **確認の方法と限界**
> - Anthropic（platform.claude.com、anthropic.com/legal、privacy.claude.com）、OpenAI（developers.openai.com）、Google（ai.google.dev）、Apple（developer.apple.com のドキュメント JSON と WWDC26 セッションの書き起こし）の**本文を直接取得して読んだ**。本文で確かめた主張は「本文で確認」と書く。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 本文や関連ページを探しても記述が無かったものは「本文を探したが記述なし」と書く。実機や実 API での確認はしていない。
> - **OpenAI の法務ページ（openai.com/policies/business-terms、services-agreement、enterprise-privacy）は 403 で取得できなかった。** OpenAI のデータの扱いは developers.openai.com の「Your data」ページの本文だけを根拠にしている。
> - Gemini API のレート制限ページは、モデルごとの数値を載せず「AI Studio で確認せよ」と書いている。数値は取得していない。
> - Apple のドキュメントは JS で描画されるため、`developer.apple.com/tutorials/data/documentation/foundationmodels/*.json` から本文を読んだ。
> - モデル名と料金は**取得日（2026-09-24）時点**のもの。料金は変わる。Anthropic のモデル ID と料金は `claude-api` スキル（キャッシュ 2026-06-24）と公式ページで突き合わせ、公式ページを正とした（スキルには無い Claude Opus 5.5 が公式ページでは現行の推奨モデルになっている）。
> - 二次情報（比較ブログ、まとめ記事、コミュニティ投稿、Wikipedia）は使っていない。

## 結論の要約

- **画像入力と JSON schema による構造化出力は、Claude・GPT・Gemini の現行モデルすべてが対応する**（本文で確認）。「料理 → 材料 → 量」の入れ子の JSON を1回の呼び出しで返させることは、どの提供元でもできる。スキーマの制約は提供元で異なる（Claude は `minimum`/`maximum` 非対応、GPT は「全プロパティ必須」で上限 5,000 プロパティ・10 段、Gemini は `minimum`/`maximum` 対応だが「大きすぎる・深すぎるスキーマは拒否されることがある」）。
- **写真1枚の入力トークンは、送る前に縮小するかどうかで 3〜5 倍変わる。** iPhone の 12MP 写真（4032×3024）をそのまま送ると、Claude Opus 5.5 / Sonnet 5 で約 4,740 トークン、GPT-6 系（detail: high）で約 2,940 トークン、Gemini 3 系（既定の解像度）で 1,120 トークン。1024×768 に縮小して送ると Claude 1,036・GPT 922・Gemini 1,120（Gemini は解像度指定で 280〜2,240）。
- **写真1枚あたりの入力費用は、縮小して送れば 0.01 円台〜 1 円未満**（$1 = 150 円換算）。Gemini 3.8 Flash ≈ $0.0008、GPT-6 Luna ≈ $0.0001、Claude Haiku 4.5 ≈ $0.001、Claude Sonnet 5 ≈ $0.002、GPT-6 Sol ≈ $0.002、Claude Opus 5.5 ≈ $0.004。**費用の主因は画像ではなく、思考（reasoning）を含む出力トークンとプロンプト**になる。
- **1ユーザーあたりの月額は、1日3枚・月90枚・写真を 1024×768 に縮小・出力 500 トークンの仮定で、$0.04（GPT-6 Luna）〜 $1.6（Claude Opus 5.5）。** 中位のモデル（Claude Sonnet 5、GPT-6 Sol、Gemini 3.1 Pro）で $0.8〜0.9、安いモデル（Claude Haiku 4.5、Gemini 3.8 Flash）で $0.3〜0.4。写真を縮小せずに送ると Claude Opus 5.5 で約 $3 に増える。出し方は最後の節に書いた。
- **日本の料理の認識について公式に書いているものは無い**（3社とも本文を探したが記述なし）。OpenAI は「非ラテン文字（日本語・韓国語など）のテキストを含む画像では性能が落ちることがある」と書く（本文で確認）。Apple は多モーダルの記事で「この写真の食品をすべて挙げよ」「冷蔵庫の写真から品目を挙げてレシピ案を作る」を例に挙げる（本文で確認）。
- **Apple の Foundation Models framework は iOS 27 から画像を扱える**（`Attachment` / `ImageAttachmentContent`、iOS 27.0+、本文で確認）。ただし端末上モデルのコンテキストは 4,096 トークン、Private Cloud Compute（PCC）のモデルは 32,000 トークンで、PCC は「初回ダウンロード 200 万未満・App Store Small Business Program」の開発者に API 費用なしで開放され、利用には entitlement の申請が要る（本文で確認）。**画像1枚のトークン数・枚数の上限は本文を探したが記述なし**。
- **データの扱いは、3社とも有料 API では「学習に使わない」と書いている。** Anthropic は Commercial Terms で「Customer Content で学習しない」、保持は既定 30 日以内に削除（Fable 5.x は 30 日保持が必須）。OpenAI は「2023-03-01 以降、API に送ったデータは学習に使わない」、不正利用監視ログを最長 30 日保持、画像は CSAM 検査で該当時のみ保持。Google は有料枠で「プロンプト（画像を含む）と応答を製品改善に使わない」、無料枠は**使う**（人手レビューあり）。Apple の PCC は「プロンプトは保存しない」（WWDC26 書き起こし）。プライバシーポリシーには「無料枠の Gemini API は使わない」ことを前提に書く必要がある。

## 問い1: 画像入力と構造化出力（JSON schema）の対応

各セルの末尾の【 】が確度。出典は末尾の「出典一覧」の番号。

| 項目 | Claude（Anthropic） | GPT（OpenAI） | Gemini（Google） |
|---|---|---|---|
| 現行モデルと ID（取得日時点） | Claude Fable 5.1 `claude-fable-5-1`、Claude Opus 5.5 `claude-opus-5-5`（迷ったらこれ、と公式が案内）、Claude Sonnet 5 `claude-sonnet-5`、Claude Haiku 4.5 `claude-haiku-4-5-20251001`。「現行モデルはすべてテキストと画像の入力に対応」【本文で確認 A3】 | GPT-6 Astra `gpt-6-astra`、GPT-6 Sol `gpt-6-sol`、GPT-6 Luna `gpt-6-luna`（いずれも入力 text, image、コンテキスト 1,050,000、出力 128,000）。GPT-5.4 系（`gpt-5.4`、`-mini`、`-nano`）も掲載【本文で確認 O5,O6,O7,O8】 | Gemini 3.8 Flash `gemini-3.8-flash`、Gemini 3.5 Flash-Lite `gemini-3.5-flash-lite`、Gemini 3.1 Pro Preview `gemini-3.1-pro-preview`（いずれも入力 Text, Image, Video, Audio, PDF、入力上限 1,048,576、出力上限 65,536）【本文で確認 G6,G7,G8】 |
| 画像の送り方 | `image` コンテンツブロック。base64・URL・Files API の `file_id` の3通り。JPEG/PNG/GIF/WebP【本文で確認 A1】 | Responses API の画像入力。PNG/JPEG/WEBP/非アニメ GIF【本文で確認 O1】 | インライン（base64）または Files API。PNG/JPEG/WEBP/HEIC/HEIF【本文で確認 G1】 |
| 構造化出力の仕組み | `output_config.format` に `{type: "json_schema", schema}`。constrained decoding で「常に schema に従う」。全現行モデルで GA。旧 `output_format` は非推奨【本文で確認 A4】 | Responses API の `text.format` に `{type: "json_schema", strict: true, schema}`。「モデルは常に与えた JSON Schema に従う」。GPT-4o 以降の主要モデルで対応、`gpt-6-*` の機能表に structured_outputs【本文で確認 O3,O5】 | `response_format` に `{type: "text", mime_type: "application/json", schema}`。モデル表の「Structured outputs: Supported」（3.8 Flash、3.5 Flash-Lite、3.1 Pro Preview）【本文で確認 G3,G6,G7,G8】 |
| スキーマの対応範囲 | 基本型、`enum`、`const`、`anyOf`/`allOf`、`$ref`/`definitions`、`required`、`additionalProperties: false` 必須、文字列 `format`、配列 `minItems` は 0/1 のみ。**非対応**: 再帰、`minimum`/`maximum`/`multipleOf`、`minLength`/`maxLength`【本文で確認 A4】 | 型: string/number/boolean/integer/object/array/enum/anyOf。string の `pattern`/`format`、number の `minimum`/`maximum`/`multipleOf` 等、array の `minItems`/`maxItems`。上限: 5,000 プロパティ・入れ子 10 段・enum 合計 1,000 値・名前と enum の総文字数 120,000。ルートは object、全フィールド required、`additionalProperties: false`【本文で確認 O3】 | 型: string/number/integer/boolean/object/array/null。`enum`、`format`、`minimum`/`maximum`、`items`/`prefixItems`/`minItems`/`maxItems`、`required`/`additionalProperties`。「すべての JSON Schema 機能に対応するわけではない」「非常に大きい、または深く入れ子のスキーマは拒否されることがある」【本文で確認 G3】 |
| 画像入力と構造化出力の併用 | ユースケースに「画像やテキストからのデータ抽出」を明記【本文で確認 A4】 | 構造化出力のページに画像との併用の記述は無い。モデルの機能表では画像入力と structured_outputs が同じモデルに並ぶ【本文を探したが明確な記述なし（読み取り）O3,O5】 | 画像理解のページで、物体検出の応答を JSON（`box_2d`、`label`）で返させる例がある【本文からの読み取り G1】 |
| 構造化出力の追加コストと遅延 | 初回はスキーマの文法のコンパイルで遅延、以後 24 時間キャッシュ。出力形式を説明するシステムプロンプトが自動で足され入力トークンが少し増える。`output_config.format` を変えるとプロンプトキャッシュが無効になる【本文で確認 A4】 | 本文を探したが記述なし | 本文を探したが記述なし |
| 量の推定に効く数値制約 | `minimum`/`maximum` が使えないので「量は 0 以上」はプロンプトで指示するか、後段で検証する【本文からの読み取り A4】 | `minimum`/`maximum`/`multipleOf` が使える【本文で確認 O3】 | `minimum`/`maximum` が使える【本文で確認 G3】 |

## 問い2: 画像1枚あたりの料金、レート制限、枚数と大きさの上限

### 料金（取得日 2026-09-24 時点、USD / 100 万トークン）

| 項目 | Claude（Anthropic） | GPT（OpenAI） | Gemini（Google） |
|---|---|---|---|
| 上位モデル | Fable 5.1: 入力 $10 / 出力 $50。Opus 5.5: 入力 $4 / 出力 $20（キャッシュ読み $0.20）【本文で確認 A2】 | GPT-6 Astra: 入力 $10 / キャッシュ入力 $1 / 出力 $50【本文で確認 O2,O5】 | Gemini 3.1 Pro Preview: 入力 $2（20 万トークン以下）/ 出力 $12。無料枠なし【本文で確認 G2】 |
| 中位モデル | Sonnet 5: 入力 $2 / 出力 $10（キャッシュ読み $0.20）。導入価格が恒久化され、2026-09-01 の値上げは行われなかった【本文で確認 A2】 | GPT-6 Sol: 入力 $2 / キャッシュ入力 $0.20 / 出力 $10（キャッシュ書き込みは入力の 1.25 倍）【本文で確認 O2,O6】 | Gemini 3.5 Flash: 入力 $1.50 / 出力 $9。Gemini 3.8 Flash: 入力 $0.75 / 出力 $3.75（2026-12-31 まで。**2027-01-01 から $1.50 / $7.50**）【本文で確認 G2】 |
| 下位モデル | Haiku 4.5: 入力 $1 / 出力 $5（キャッシュ読み $0.10）【本文で確認 A2】 | GPT-6 Luna: 入力 $0.10 / キャッシュ入力 $0.01 / 出力 $0.50。GPT-5.4-nano: $0.20 / $1.25【本文で確認 O2,O7】 | Gemini 3.5 Flash-Lite: 入力 $0.30 / 出力 $2.50【本文で確認 G2】 |
| バッチ割引 | 入力・出力とも 50% 引き【本文で確認 A2】 | 「バッチ価格はおおむね 50% 引き」【本文で確認 O2】 | 50% 引き【本文で確認 G2】 |
| 画像の課金単位 | 画像は 28×28 px のパッチ = 1 visual token として入力トークンに数える。`⌈幅/28⌉ × ⌈高さ/28⌉`【本文で確認 A1】 | 画像は 32×32 px のパッチに分け、モデル別の倍率（GPT-6/5.6/5.5/5.4 系は 1.2）を掛けて入力トークンに数える。画像トークンは TPM 制限にも数える【本文で確認 O1】 | Gemini 3 系は `media_resolution` で画像1枚のトークン上限を決める: 既定 1,120、low 280、medium 560、high 1,120、ultra_high 2,240。Gemini 2.x 系は 384 px 以下 258 トークン、それ以上は 768×768 のタイルごとに 258【本文で確認 G1,G4】 |
| 解像度の上限（縮小のされ方） | 高解像度ティア（Claude 4.7 以降 = Opus 5.5、Sonnet 5、Fable 5.1）: 長辺 2,576 px・4,784 トークンまで。標準ティア（Haiku 4.5 など）: 長辺 1,568 px・1,568 トークンまで。超える画像は縦横比を保って縮小される。公式の参照実装あり【本文で確認 A1,A5】 | `detail: high` は 2,048×2,048 に収め 2,500 パッチまで（GPT-6 Sol/Luna、GPT-5.5/5.4）。`low` は 512×512 に収める。`original` は 65,535 px・30,000 パッチまで【本文で確認 O1】 | 上記の `media_resolution` のトークン上限に収まるよう処理される（縮小の具体的な規則は本文を探したが記述なし）【本文で確認 G4】 |
| **iPhone の 12MP 写真（4032×3024）をそのまま送ったとき** | 高解像度ティア: 2212×1659 に縮小、**4,740 トークン**。標準ティア: 1270×952 に縮小、**1,564 トークン**（公式の参照実装で計算）【本文からの読み取り A5】 | `detail: high`: 2,048×1,536 → 2,500 パッチ以内に縮小、**約 2,940 トークン**（公式の手順で計算。公式の例では 2048×2048 が 3,000 トークン）【本文からの読み取り O1】 | 既定（unspecified）: **1,120 トークン**。ultra_high: 2,240【本文で確認 G4】 |
| **1024×768 に縮小して送ったとき** | 37×28 = **1,036 トークン**（どのティアでも縮小されない）【本文からの読み取り A1】 | 32×24 = 768 パッチ × 1.2 = **922 トークン**【本文からの読み取り O1】 | 既定 **1,120 トークン**（サイズによらず上限で決まる）。low なら 280【本文からの読み取り G4】 |
| **写真1枚の入力費用（1024×768、USD）** | Haiku 4.5 ≈ $0.0010、Sonnet 5 ≈ $0.0021、Opus 5.5 ≈ $0.0041【計算】 | GPT-6 Luna ≈ $0.0001、GPT-6 Sol ≈ $0.0018、GPT-6 Astra ≈ $0.0092【計算】 | Gemini 3.8 Flash ≈ $0.0008、3.5 Flash-Lite ≈ $0.0003、3.1 Pro ≈ $0.0022【計算】 |
| 公式が示す画像費用の例 | 「Haiku 4.5（$1/MTok）で 1000×1000 の画像は 1,000 枚あたり約 $1.30。Opus 5（$5/MTok、高解像度ティア）で同じ画像が 1,000 枚あたり約 $6.48、4K 画像は約 $23.92」【本文で確認 A1】 | 「gpt-6-astra、detail: high で 1024×1024 は 1,229 トークン、2048×2048 は 3,000 トークン、4096×512 は 2,458 トークン」【本文で確認 O1】 | Gemini 3 Pro Image のバッチ価格に「画像入力 $0.0006/枚」の記載があるが、これは画像生成モデルの項【本文で確認 G2】 |

### レート制限

| 項目 | Claude（Anthropic） | GPT（OpenAI） | Gemini（Google） |
|---|---|---|---|
| ティアの決まり方 | 利用履歴と口座の状態で自動配置。Start / Build / Scale / Custom。新規組織は Evaluation ティアで標準より低い上限から始まることがある【本文で確認 A6】 | 累計支払額で自動昇格。Tier 1: $5、Tier 2: $50、Tier 3: $100、Tier 4: $250、Tier 5: $1,000【本文で確認 O4】 | 課金アカウントの紐付けと支払実績。Tier 1: 課金アカウント紐付け、Tier 2: $100 支払い＋初回支払いから 3 日、Tier 3: $1,000 支払い＋30 日【本文で確認 G5】 |
| 月の支出上限 | Start $500、Build $1,000、Scale $200,000。上限に達すると翌月 1 日 00:00 UTC まで 429【本文で確認 A6】 | Free/Tier 1 $100/月、Tier 2 $500、Tier 3 $1,000、Tier 4 $5,000、Tier 5 $200,000【本文で確認 O4】 | Tier 1 $250、Tier 2 $2,000、Tier 3 $20,000〜100,000+【本文で確認 G5】 |
| 最初のティアの上限（写真推定に使うモデル） | Start: Opus 5.5 / Sonnet 5 / Haiku 4.5 とも 1,000 RPM、入力 2,000,000 トークン/分、出力 400,000 トークン/分。モデルごとに別枠。キャッシュ読みのトークンは入力上限に数えない【本文で確認 A6】 | Tier 1: gpt-6-astra / gpt-6-sol / gpt-6-luna とも 500 RPM、500,000 TPM。画像トークンは TPM に数える【本文で確認 O1,O5,O6,O7】 | 「レート制限は利用ティアなどで決まり、Google AI Studio で確認できる」「明示された上限は保証されず、実際の容量は変わりうる」。モデル別の数値はページに無い。RPM・TPM・RPD の3軸、プロジェクト単位【本文で確認 G5】 |
| 1ユーザー数千人規模での見込み | 1,000 RPM = 1 秒あたり約 16 回。食事の時間帯に集中しても最初のティアで足りる可能性が高い（推定）【本文からの読み取り A6】 | 500 RPM × 平均 4,000 トークン = 2,000,000 TPM 相当だが TPM 上限は 500,000 なので、**Tier 1 では 1 分あたり約 125 回**が上限になる（推定）【本文からの読み取り O5,O6】 | 数値が無いので見積もれない【記述なし G5】 |

### 1回の呼び出しで送れる画像の枚数と大きさ

| 項目 | Claude（Anthropic） | GPT（OpenAI） | Gemini（Google） |
|---|---|---|---|
| 枚数 | API で 1 リクエスト 600 枚（200k コンテキストのモデル = Haiku 4.5 は 100 枚）。20 枚を超えると各画像 2,000 px の制限が加わる【本文で確認 A1】 | 1 リクエスト 1,500 枚【本文で確認 O1】 | 1 リクエスト 3,600 枚【本文で確認 G1】 |
| 1枚の大きさ | 8,000×8,000 px まで。base64 で 10 MB（Bedrock/Google Cloud は 5 MB）。リクエスト全体 32 MB【本文で確認 A1】 | 1枚 30,000 パッチまで（縮小後）。辺 65,535 px。リクエスト全体 512 MB【本文で確認 O1】 | インラインはリクエスト全体（テキスト・システム指示・画像を合わせて）20 MB。Files API は 1 ファイル 2 GB、プロジェクト 20 GB、48 時間保持【本文で確認 G1,G9】 |
| 画像のメタデータ | 「Claude は画像のメタデータを受け取らない」【本文で確認 A1】 | 「元のファイル名やメタデータは処理しない」【本文で確認 O1】 | 本文を探したが記述なし |
| 品質上の注意 | 200 px 未満・回転・低品質で誤りが増える。数え上げは近似。テキストが重要なら読める大きさに。圧縮の劣化に注意【本文で確認 A1】 | 医用画像不可、非ラテン文字のテキスト、小さい文字、回転、パノラマ・魚眼、数え上げは近似、CAPTCHA 拒否【本文で確認 O1】 | 「画像の向きが正しいか確かめる」「ぼやけていない画像を使う」「1枚の画像とテキストでは、テキストを画像の**前**に置く」【本文で確認 G1】 |
| 画像とテキストの順序 | 「画像をテキストの前に置くと最もよく働く」【本文で確認 A1】 | 本文を探したが記述なし | 「テキストを画像の前に置く」【本文で確認 G1】 |

## 問い3: 日本の料理の認識について各社が公式に書いていること

| 提供元 | 所見 | 確度 | 出典 |
|---|---|---|---|
| Anthropic | Vision のページ、Vision のベストプラクティスのクックブックに、料理・食事・和食・日本の記述は無い。クックブックの食品に近い例はレストランのレシートの読み取りだけ。「デジタルレシピカードを作る」というユースケース紹介ページがあるが、写真から料理を当てる話ではない | 本文を探したが記述なし | A1、A7 |
| OpenAI | 料理・食事・和食の記述は無い。制限事項に「**非ラテン文字（日本語や韓国語など）のテキストを含む画像では、モデルの性能が最適でないことがある**」とある（写真のパッケージや店のメニューの文字を読む場面に関わる） | 本文を探したが記述なし（非ラテン文字の制限だけ本文で確認） | O1 |
| Google | 画像理解のページに料理・和食・非英語の記述は無い。能力として「キャプション、分類、VQA、物体検出、セグメンテーション」を挙げる。ai.google.dev にある「Nutritionist-Food-Recognition-Gemini-Pro」は開発者コンテストの応募作品のページで、Google の公式見解ではないため使わない | 本文を探したが記述なし | G1 |
| Apple | 「Analyzing images with multimodal prompting」に、多モーダルの用途として「**冷蔵庫の写真の中の品目を挙げてレシピ案を作る**」、プロンプトの書き方の例として「『この画像に何がある?』ではなく『**この写真の食品をすべて挙げよ**』と書く」がある。和食・日本の料理の記述は無い。対応言語に ja-JP を含む | 食品の例は本文で確認。和食は記述なし | P5、P7 |

## 問い4: Apple の端末上モデル（Foundation Models framework）が画像を扱えるか

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 画像入力の可否 | できる。`Attachment` に `CGImage`・`CIImage`・`CVPixelBuffer`・画像ファイルの URL を渡してプロンプトに混ぜる。`ImageAttachmentContent` は **iOS 27.0+ / iPadOS 27.0+ / macOS 27.0+ / visionOS 27.0+ / watchOS 27.0+**。iOS 26 の `Prompt` は文字列だけ | 本文で確認 | P2、P3、P4 |
| 端末上モデルで画像を扱えるか | WWDC26「What's new in the Foundation Models framework」: 「**端末上モデルもビジョン機能を得る**。UIImage、NSImage、CGImage、Core Image、CoreVideo のピクセルバッファ、ファイル URL を受け付ける」。多モーダルの記事も「まず端末上モデルで画像分析を行い、さらに推論や文脈が要るなら `PrivateCloudComputeLanguageModel` を使う」と書く | 本文で確認 | P6、P5 |
| 画像の大きさ・枚数の上限 | 「どんなサイズ・縦横比の画像でも対応するので、切り抜きやパディングは不要。ただし**大きい画像ほどトークンを多く消費し、遅延が増える**」。フレームワークが拡大縮小と色変換を行う。画像1枚のトークン数の式、枚数の上限は本文を探したが記述なし | サイズの自由度は本文で確認。トークン数の式・枚数は記述なし | P6、P5 |
| コンテキスト（トークン数） | 端末上のシステムモデルは **4,096 トークン**。「日本語・中国語・韓国語では 1 文字が 1 トークン」。1 セッションの instructions・prompts・outputs の合計がコンテキストに数えられる。iOS 26.4 から `contextSize` と `tokenCount(for:)` で確認できる | 本文で確認 | P1、P6 |
| 構造化出力 | `@Generable` の guided generation。多モーダルの記事に、画像を `@Generable enum` のラベルに分類する例（`samplingMode: .greedy` 推奨）。`@Generable struct` で入れ子の構造も作れる | 本文で確認 | P5、P7 |
| 追加のツール | Vision framework の OCR ツールとバーコード読み取りツールをセッションに足せる。自前のツールで `ImageReference` を受け取り、Vision の `ClassifyImageRequest` などを呼べる | 本文で確認 | P5 |
| Private Cloud Compute（PCC）のモデル | `PrivateCloudComputeLanguageModel`（27.0+）。「端末上モデルよりずっと大きく、**32,000 トークン**のコンテキストと reasoning（`reasoningLevel`）を持つ」。「初回ダウンロード 200 万未満の開発者に**クラウド API 費用なし**」。「ユーザーは毎日 PCC を使え、iCloud+ 加入者は上限がさらに高い」（1日あたりの具体的な回数は記述なし）。利用には **entitlement の申請**と App Store Small Business Program の条件があり、200 万を超えると 6 か月以内に別の手段へ移行する必要がある。`quotaUsage` で残量を確認できる | 本文で確認 | P6、P8、P9 |
| PCC のプライバシー | 「アカウント設定・認証・API キーの保管が不要」「**プロンプトは一切保存されない**。独立した研究者が検証できる」 | 本文で確認（WWDC26 の書き起こし） | P6 |
| 利用できる端末 | 「Apple Intelligence に対応した端末が必要」。`availability` で `deviceNotEligible` / `modelNotReady` を判定する | 本文で確認 | P1、P3 |
| 対応言語 | de-DE、en-US、es-419、fr-FR、it-IT、ja-JP、ko-KR、pt-BR、zh-CN。`supportsLocale()` で確認 | 本文で確認 | P7 |
| 得意・不得意 | 得意: 要約、エンティティ抽出、テキストと画像の理解、分類、タグ生成。不向き: 「基本的な計算」「コード生成」「論理的推論」 | 本文で確認 | P1 |

nu-tori への含意: 端末上モデルは無料でプライバシーも最良だが、コンテキスト 4,096 トークン（日本語 1 文字 = 1 トークン）に写真と「料理 → 材料 → 量」の出力を収める必要があり、「基本的な計算は不向き」と公式が書くので**量や栄養の計算は端末上モデルに任せず、モデルは料理名と材料名の列挙に絞り、量と栄養はアプリ側の食品データベースと計算で出す**構成が現実的（本文からの読み取り）。PCC は 32K・reasoning つき・費用なしで有力だが、entitlement の申請と Small Business Program の条件、1日あたりの回数制限（数値未公開）を確かめる必要がある。

## 問い5: データの扱い（学習への利用、保持期間、商用規約）

| 項目 | Claude（Anthropic） | GPT（OpenAI） | Gemini（Google） | Apple |
|---|---|---|---|---|
| 送った写真を学習に使うか | 使わない。Commercial Terms（2025-06-17 発効）「**Anthropic may not train models on Customer Content from Services**」。Vision の FAQ「Anthropic は送られた画像をモデルの学習に使わない」。プライバシーセンター（2026-08-18）「商用製品（API など）の入力・出力は既定で学習に使わない。フィードバック（👍👎）を送った場合は例外」【本文で確認 A8,A1,A9】 | 使わない。「**As of March 1, 2023, data sent to the OpenAI API is not used to train or improve OpenAI models**（明示的にオプトインしない限り）」【本文で確認 O9】 | **有料枠**: 「Google はプロンプト（システム指示、キャッシュ、**画像・動画・文書などのファイルを含む**）や応答を製品改善に使わない」。**無料枠**: 「送信した内容と生成された応答を、Google 製品の提供・改善・開発に使う」「人手のレビュアーが API の入出力を読み、注釈し、処理することがある」「**機微・機密・個人情報を無料サービスに送らないこと**」。EEA・スイス・英国のユーザーは無料でも有料の条件が適用される。Gemini API 追加規約は 2026-03-23 発効【本文で確認 G10,G2】 | PCC: 「プロンプトは一切保存されない」【本文で確認 P6】。端末上モデルはデータが端末を出ない前提だが、その旨の明文は読んだページには無い【本文からの読み取り P3】 |
| 入力・出力の保持期間 | 「API の入力と出力はバックエンドで**受領・生成から 30 日以内に自動削除**」（2026-07-01 付）。API 文書: 「会話の内容は既定で保持しない。例外は Covered Models（**Fable 5.1 / Mythos 5.1 / Fable 5 / Mythos 5**）で 30 日保持が必須」。ゼロデータ保持（ZDR）は契約で可能だが Covered Models は対象外。Files API は削除するか期限まで保持。構造化出力は JSON schema だけを最長 24 時間キャッシュ。Usage Policy 違反時は最長 2 年【本文で確認 A10,A11】 | 「不正利用監視ログ（プロンプト・応答・分類器の出力を含みうる）は既定で全 API 機能について生成され、**最長 30 日**保持」。承認を受ければ Zero Data Retention または Modified Abuse Monitoring を選べる。**画像とファイルの入力は送信時に CSAM 検査され、該当が疑われると ZDR でも人手レビューのため保持される**。データ保存の所在地（data residency）に日本を選べる【本文で確認 O9】 | 有料枠: 「Prohibited Use Policy の違反の検知・防止のためだけに、**プロンプトと応答を限られた期間ログする**」（日数の明示なし）。「データは Google やその代理人が施設を持つどの国でも一時保存・キャッシュされうる」。Files API のファイルは **48 時間**保持【本文で確認 G10,G9】 | PCC: 「保存しない」【本文で確認 P6】 |
| 入力・出力の権利 | 「Customer は Inputs のすべての権利を保持し、Outputs を所有する」【本文で確認 A8】 | Business Terms は 403 で取得できず。Your data ページの「Your data is your data」のみ【取得できず / 本文で確認 O9】 | 本文を探したが記述なし（Gemini API 追加規約の該当節は今回の取得範囲で確認できず）【記述なし】 | — |
| データ処理の規定（DPA） | Commercial Terms に DPA（2025-02-24 発効）を参照により組み込み。「Customer が管理者、Anthropic が処理者」。契約終了後 30 日以内に Customer Data を削除【本文で確認 A8,A12】 | Your data ページに DPA の記述なし。Business Terms は取得できず【取得できず】 | 有料枠は「Data Processing Addendum for Products Where Google is a Data Processor」に従って処理【本文で確認 G10】 | — |
| モデルによる例外 | Fable 5.1 / Fable 5 は 30 日保持が必須で、ZDR 組織からの要求は `400 invalid_request_error`。Opus 5.5 / Sonnet 5 / Haiku 4.5 にこの制約は無い【本文で確認 A11】 | 「特定の顧客について、モデルを ZDR / MAM の対象外にする権利を留保する」（Private Retention / Safety Retention）【本文で確認 O9】 | 本文を探したが記述なし | — |
| プライバシーポリシー（#34）に書ける根拠 | 「写真は Anthropic の API に送られ、モデルの学習には使われず、30 日以内に削除される。ゼロ保持の契約は別途」 | 「写真は OpenAI の API に送られ、学習には使われず、不正利用監視のため最長 30 日保持される。児童性的虐待コンテンツの検査に該当した場合は保持されうる」 | 「**有料枠に限り**、写真は製品改善に使われず、違反検知のため限られた期間ログされる」。無料枠を使う構成ではこの記述ができない | 「PCC ではプロンプトが保存されない。端末上では写真は端末を出ない」（後者は Apple の文面での裏付けを要確認） |

## 次の判断に効くこと

### #28（推定の仕組みの決定）に向けて、比べる軸ごとの要点

1. **構造の返し方**: 3社とも「料理 → 材料 → 量」を1つの JSON schema で1回で返せる。段階的推定（料理 → 材料 → 食品データベース）にする場合も、各段を構造化出力で受ければ実装の差は小さい。スキーマの制約だけ違う（Claude は数値の `minimum`/`maximum` が使えないので、量の妥当性はアプリ側で検証する）。
2. **画像の前処理を先に決める**: 送る前に長辺 1,024〜1,280 px 程度に縮小するのが、どの提供元でも費用と遅延に最も効く（Claude は 4,740 → 約 1,000、GPT は 2,940 → 約 900）。Gemini は縮小の有無で変わらず `media_resolution` で決まる。縮小しすぎると Claude の注意書き（200 px 未満で誤りが増える、小さい文字が読めない）に当たるので、市販品のパッケージ表示を読む場面では高めに保つ。
3. **費用の主因は出力トークン**: 画像は 1,000 トークン前後で済むが、日本語の料理名・材料名を含む JSON の出力（500 トークン仮定）と、思考（reasoning）のトークンが出力単価で課金される。Claude Opus 5.5 は思考を切れず、Sonnet 5 は切れる（`claude-api` スキルの記述。公式ページでは未確認）。GPT の reasoning トークン、Gemini の thinking トークンも同様に出力扱いになるかは今回のページでは確認していない。**評価では `usage` の出力トークン数を必ず記録する。**
4. **レート制限**: Claude は最初のティアでも 1,000 RPM・2M ITPM でモデル別に枠がある。OpenAI は Tier 1 が 500 RPM・500,000 TPM で、画像トークンが TPM に数えられるため 1 分あたり 100 回強が上限になる。Gemini は数値が公開されておらず AI Studio で確認する必要がある。
5. **日本の料理**: どこにも公式の記述が無いので、`docs/ui-design/0001-first-release/index.md` の「出荷後の検証」（約 30 食、カロリーとタンパク質の誤差率とばらつき）をそのまま比較の物差しにする。OpenAI の「非ラテン文字のテキスト」の注意は、パッケージ表示や店のメニューを写す場面で効く。
6. **Apple の端末上モデル**: iOS 27 で画像を扱えるので、「料理名と材料名の列挙」だけを端末上で無料・オフラインで行い、量と栄養はアプリ側で出す構成は検討に値する。ただし ADR-0004 で iOS の最低版は決まっていないため、iOS 27 を要求するかは別に決める。コンテキスト 4,096 トークンと「計算は不向き」の制約、PCC の entitlement と回数制限（数値未公開）を確かめてから決める。
7. **切り替えやすさ**: 3社とも入力は「画像ブロック + テキスト」、出力は JSON schema なので、推定の入出力をアプリ側で提供元に依存しない形（料理・材料・量の構造）に固定しておけば、後から提供元を変えられる。ADR-0005 の「推定結果を料理と材料に分けて保存すれば構造は保てる」と整合する。

### #34（プライバシーポリシー）に向けて

- 「写真を第三者（AI の提供元）に送る」「学習には使われない」「保持期間」の3点は、上の問い5の表の最下行の文面で書ける。提供元を決めるまでは、3社に共通する「学習に使われない」「最長 30 日程度の保持」で書き、確定後に提供元名と URL を入れる。
- Gemini を使うなら**有料枠であること**が前提条件になる。無料枠は「製品改善に使う・人手レビューあり・個人情報を送るな」と明記されている。
- OpenAI を使うなら、画像入力の CSAM 検査と該当時の保持について触れるかを決める。
- Apple の PCC を使うなら「プロンプトは保存されない」と書けるが、Apple の文書（WWDC の書き起こしではなく規約）での裏付けを取ってから書く。

### 1ユーザーあたりの月額費用の概算の出し方

```mermaid
flowchart LR
  A[月の写真枚数<br/>= 1日の食事回数 × 日数] --> E
  B[写真1枚の入力トークン<br/>= 縮小後のサイズから各社の式で] --> E
  C[プロンプトのトークン<br/>= システム指示 + スキーマの説明<br/>（キャッシュで単価を下げられる）] --> E
  D[出力トークン<br/>= JSON の本文 + 思考のトークン] --> E
  E[1回の費用<br/>= (B + C) × 入力単価 + D × 出力単価] --> F[月額 = E × A]
```

仮定: 1日3枚・月90枚、写真は 1024×768 に縮小、プロンプト 1,000 トークン（キャッシュなし）、出力 500 トークン（思考なし）。単価は取得日時点。

| モデル | 1回の入力トークン | 1回の費用（USD） | 月額（USD、90回） |
|---|---|---|---|
| Claude Haiku 4.5（$1 / $5） | 1,036 + 1,000 | 0.0020 + 0.0025 = 0.0045 | **0.41** |
| Claude Sonnet 5（$2 / $10） | 1,036 + 1,000 | 0.0041 + 0.0050 = 0.0091 | **0.82** |
| Claude Opus 5.5（$4 / $20） | 1,036 + 1,000 | 0.0081 + 0.0100 = 0.0181 | **1.63** |
| GPT-6 Luna（$0.10 / $0.50） | 922 + 1,000 | 0.0002 + 0.0003 = 0.0005 | **0.04** |
| GPT-6 Sol（$2 / $10） | 922 + 1,000 | 0.0038 + 0.0050 = 0.0088 | **0.80** |
| Gemini 3.8 Flash（$0.75 / $3.75、2026 年内） | 1,120 + 1,000 | 0.0016 + 0.0019 = 0.0035 | **0.31**（2027 年から 0.62） |
| Gemini 3.1 Pro Preview（$2 / $12） | 1,120 + 1,000 | 0.0042 + 0.0060 = 0.0102 | **0.92** |
| Apple 端末上 / PCC | — | 0（PCC は条件つき） | **0** |

写真を縮小せず 12MP のまま送ると、Claude の高解像度ティアは入力が 4,740 トークンになり月額は Sonnet 5 で約 $1.5、Opus 5.5 で約 $3 に増える。思考を有効にすると出力トークンが数倍になりうるので、実測で置き換える。段階的推定（料理 → 材料を 2 回に分ける）にすると、写真を 2 回送る分だけ入力が増える（Claude は同じ画像を 2 回送っても課金は 2 回分）。バッチ API は 50% 引きだが非同期なので、撮った直後に結果を見せる nu-tori の流れには合わない。プロンプトキャッシュはシステム指示とスキーマの分だけ効く（Claude はキャッシュ読みが入力の 10%、Opus 5.5 は 5%）。

## 出典一覧

すべて 2026-09-24 に本文を取得。

### Anthropic
- A1: Vision — https://platform.claude.com/docs/en/build-with-claude/vision
- A2: Pricing — https://platform.claude.com/docs/en/about-claude/pricing
- A3: Models overview — https://platform.claude.com/docs/en/about-claude/models/overview
- A4: Structured outputs — https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- A5: Coordinates and bounding boxes（縮小の規則と参照実装） — https://platform.claude.com/docs/en/build-with-claude/vision-coordinates
- A6: Rate limits — https://platform.claude.com/docs/en/api/rate-limits
- A7: Best practices for using vision（クックブック） — https://platform.claude.com/cookbook/multimodal-best-practices-for-vision
- A8: Commercial Terms of Service（2025-06-17 発効） — https://www.anthropic.com/legal/commercial-terms
- A9: Is my data used for model training?（2026-08-18） — https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training
- A10: How long do you store my organization's data?（2026-07-01） — https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data
- A11: API and data retention（Covered Models、ZDR の対象） — https://platform.claude.com/docs/en/manage-claude/api-and-data-retention 、What's new in Claude Fable 5.1 — https://platform.claude.com/docs/en/models/fable-5-1/whats-new-fable-5-1
- A12: Data Processing Addendum（2025-02-24 発効） — https://www.anthropic.com/legal/data-processing-addendum

### OpenAI
- O1: Images and vision（画像の要件、トークン計算、制限事項） — https://developers.openai.com/api/docs/guides/images-vision
- O2: Pricing — https://developers.openai.com/api/docs/pricing
- O3: Structured Outputs（Supported schemas） — https://developers.openai.com/api/docs/guides/structured-outputs
- O4: Rate limits（利用ティア） — https://developers.openai.com/api/docs/guides/rate-limits
- O5: gpt-6-astra — https://developers.openai.com/api/docs/models/gpt-6-astra
- O6: gpt-6-sol — https://developers.openai.com/api/docs/models/gpt-6-sol
- O7: gpt-6-luna — https://developers.openai.com/api/docs/models/gpt-6-luna
- O8: Models — https://developers.openai.com/api/docs/models
- O9: Your data（学習、保持、ZDR、画像の CSAM 検査） — https://developers.openai.com/api/docs/guides/your-data
- 取得できず（HTTP 403）: https://openai.com/policies/business-terms/ 、https://openai.com/policies/services-agreement/ 、https://openai.com/enterprise-privacy/

### Google
- G1: Image understanding — https://ai.google.dev/gemini-api/docs/image-understanding
- G2: Pricing — https://ai.google.dev/gemini-api/docs/pricing
- G3: Structured output — https://ai.google.dev/gemini-api/docs/structured-output
- G4: Media resolution — https://ai.google.dev/gemini-api/docs/media-resolution
- G5: Rate limits — https://ai.google.dev/gemini-api/docs/rate-limits
- G6: Gemini 3.8 Flash — https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash
- G7: Gemini 3.1 Pro Preview — https://ai.google.dev/gemini-api/docs/models/gemini-3.1-pro-preview
- G8: Gemini 3.5 Flash-Lite — https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite
- G9: Files API — https://ai.google.dev/gemini-api/docs/files
- G10: Gemini API Additional Terms of Service（2026-03-23 発効） — https://ai.google.dev/gemini-api/terms

### Apple
- P1: Generating content and performing tasks with Foundation Models（4,096 トークン、得意・不得意） — https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models
- P2: Foundation Models（フレームワークの概要、対応 OS） — https://developer.apple.com/documentation/foundationmodels
- P3: SystemLanguageModel — https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- P4: Attachment / ImageAttachmentContent（iOS 27.0+） — https://developer.apple.com/documentation/foundationmodels/attachment 、https://developer.apple.com/documentation/foundationmodels/imageattachmentcontent
- P5: Analyzing images with multimodal prompting — https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- P6: What's new in the Foundation Models framework（WWDC26、書き起こし） — https://developer.apple.com/videos/play/wwdc2026/241/
- P7: Supporting languages and locales with Foundation Models — https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- P8: PrivateCloudComputeLanguageModel — https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel
- P9: Private Cloud Compute（開発者向け、条件と entitlement） — https://developer.apple.com/private-cloud-compute/
