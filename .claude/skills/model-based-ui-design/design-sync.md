# ⑦ ルック&フィール ＝ Claude Design 往復

[block-3-expression.md](block-3-expression.md) の⑦で、**単位ビューをコンポーネント単位**にして、ローカル HTML ⇄ Claude Design の design-system プロジェクトを**1コンポーネントずつ**往復し、色・タイポ・グラフィックを作り込む。

本書はデザインシステム構築を対象外とする。これは本書の単位ビュー＋「同じ性質の構造はパターン化して再利用」を土台に乗せた**拡張**である。

## コンポーネントの作り方

- 単位ビュー1つ＝1コンポーネント。`07-components/<名前>/index.html` に、概念オブジェクトのコンテンツ＋CRUD アクションを含むプレビュー HTML を書く。
- ファイル**先頭行**に `<!-- @dsCard group="Views" -->` を置く。Claude Design の Design System ペインはこの行からカードを作る（`group` はセクション区分の自由記述ラベル、最大64文字）。

## 往復（DesignSync が使える環境）

ユーザーに `/design-sync` スキルを起動してもらい、その手順と DesignSync ツールの説明に従う。このメソッドから渡す前提は次の3つ:

- 同期元ディレクトリは `07-components/`
- 同期先は design-system 型のプロジェクト（通常プロジェクトに push しても design system にはならない）
- **1コンポーネントずつ**同期し、Claude Design 側で磨いた結果は次の往復で読み戻してローカルに反映する

## フォールバック（DesignSync が無い環境）

往復ツールが無くても⑦は止めない:

- `@dsCard` 付きのコンポーネント HTML を `07-components/` にローカル生成する（後で Claude Design に取り込めば即カード化できる形）。
- [visual-output.md](visual-output.md) の道具で表示を確認しながら、色・タイポ・グラフィックをローカルで作り込む。
- ユーザーに「このコンポーネント群を Claude Design に取り込んで磨ける」ことを伝える。

往復ができないだけで、成果物（再利用可能なコンポーネント）は同じ形で残る。
