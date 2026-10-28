// PROTOTYPE（prototype/lp-a-d-section の枝だけに置く。main と PR #809 には入れない）
// 問い: D 節で「アプリが裏で進めるので、使う人を待たせない」を、技術の言葉を使わずにどう見せるか。
// 3案を同じページに並べ、?variant=A|B|C と下の切り替えの帯（/prototype-d-switcher.js）で1つだけ見せる
import { AppMealCard } from "./app-meal-card";
import type { ExamplePhotoMeal } from "./example-photo-meals";

export const DSectionPrototype = ({ curry }: { curry: ExamplePhotoMeal }) => (
  <>
    <section class="lp-band" data-proto-variant="A" data-proto-name="あなたと nu-tori の2本の線">
      <VariantA />
    </section>
    <section class="lp-band" data-proto-variant="B" data-proto-name="カードの3つの姿" hidden>
      <VariantB curry={curry} />
    </section>
    <section class="lp-band" data-proto-variant="C" data-proto-name="昼ごはんの時間割" hidden>
      <VariantC curry={curry} />
    </section>
  </>
);

// A: 使う人がすることと、アプリが進めることを、同じ時の流れに2列で並べる。使う人の列でアプリを開いているのは最初の段だけ
const VariantA = () => (
  <div class="lp-wrap">
    <h2>アプリを開いているのは、撮る数秒だけです</h2>
    <p>撮ったら閉じてかまいません。送る・読む・数えるは、あなたが食べているあいだに進みます。</p>
    <div class="proto-lanes">
      <p class="proto-lane-head" />
      <p class="proto-lane-head">あなた</p>
      <p class="proto-lane-head">nu-tori</p>

      <p class="proto-lane-when">撮る</p>
      <p class="proto-lane-you proto-lane-open">料理が来たら1枚撮って、閉じる</p>
      <p class="proto-lane-app">写真を受け取る</p>

      <p class="proto-lane-when">食べる</p>
      <p class="proto-lane-you">すぐ食べはじめる</p>
      <p class="proto-lane-app">
        写真を送って、料理と材料と量を読む
        <span class="proto-lane-note">
          インターネットにつながらない店なら、つながってから送る
        </span>
      </p>

      <p class="proto-lane-when">あとで</p>
      <p class="proto-lane-you proto-lane-open">開いて見る。違っていたら直す</p>
      <p class="proto-lane-app">読み終わって、数えてある</p>
    </div>
    <p class="proto-lane-key">
      <span class="proto-lane-key-open" />
      アプリを開いているところ
    </p>
  </div>
);

// B: タイムラインの食事のカードが、撮ってから読み終わるまでに見せる3つの姿を、アプリの描き方どおりに並べる
// （まだ届いていない記録は薄く（UndeliveredRecordStyle）、推定中は回る印と「推定しています…」（MealCardState.statusLine））
const VariantB = ({ curry }: { curry: ExamplePhotoMeal }) => (
  <div class="lp-wrap">
    <h2>記録のために、待つことはありません</h2>
    <p>撮った食事は、アプリが送って、読んで、数えます。そのあいだ、アプリを開いておく必要はありません。</p>
    <ol class="lp-steps lp-numbered proto-states">
      <li>
        <div class="app-meal proto-undelivered" aria-hidden="true">
          <img src={curry.photo.src} alt="" width="800" height="600" loading="lazy" />
          <div class="app-meal-body proto-empty-body" />
        </div>
        <b>つながらない店でも撮れる</b>
        <span>インターネットにつながらないあいだは薄く出て、つながったら送ります。</span>
      </li>
      <li>
        <div class="app-meal" aria-hidden="true">
          <img src={curry.photo.src} alt="" width="800" height="600" loading="lazy" />
          <div class="app-meal-body">
            <span class="proto-spinner" />
            <span class="app-secondary proto-status">推定しています…</span>
          </div>
        </div>
        <b>閉じて食べはじめる</b>
        <span>読むのは、あなたが食べているあいだに進みます。</span>
      </li>
      <li>
        <div aria-hidden="true">
          <AppMealCard entry={{ kind: "photo", meal: curry }} />
        </div>
        <b>開けば出ている</b>
        <span>何をどれだけと読んだかが見られます。違っていたら、そこで直せます。</span>
      </li>
    </ol>
  </div>
);

// C: 地下の店で昼ごはんを食べた日を時刻つきで追い、使う人がしたことと、そのときアプリの中で起きていたことを並べる
const VariantC = ({ curry }: { curry: ExamplePhotoMeal }) => (
  <div class="lp-wrap lp-feature">
    <div>
      <h2>撮ったら、あとはまかせて閉じられます</h2>
      <p>地下の店で昼ごはんを食べた日の、アプリの動きです。</p>
      <p class="proto-day-sum">記録のためにアプリを開いていたのは、12:30 の数秒だけです。</p>
    </div>
    <ol class="proto-day">
      <li>
        <span class="proto-day-time">12:30</span>
        <b>料理が来たので、1枚撮って閉じる</b>
        <span>写真はアプリが受け取っておきます。</span>
      </li>
      <li>
        <span class="proto-day-time">12:31</span>
        <b>すぐ食べはじめる</b>
        <span>お店はインターネットにつながりません。写真は iPhone の中で待ちます。</span>
      </li>
      <li>
        <span class="proto-day-time">13:10</span>
        <b>店を出る</b>
        <span>つながったので、写真を送って、料理と材料と量を読みます。</span>
      </li>
      <li>
        <span class="proto-day-time">15:00</span>
        <b>ふと開く</b>
        <span>もう数えてあります。違っていたら、ここで直せます。</span>
        <div class="proto-day-card" aria-hidden="true">
          <AppMealCard entry={{ kind: "photo", meal: curry }} />
        </div>
      </li>
    </ol>
  </div>
);
