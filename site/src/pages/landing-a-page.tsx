import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { landingPageHead } from "../landing-page-head";
import { AppTextMeal } from "./landing-a/app-text-meal";
import { AppMealCard } from "./landing-a/app-meal-card";
import { examplePhotoMeals } from "./landing-a/example-photo-meals";
import { exampleTextMeals } from "./landing-a/example-text-meals";
import { AppComposer } from "./landing-a/app-composer";
import { LunchDay } from "./landing-a/lunch-day";
import { MealPhotoPicker } from "./landing-a/meal-photo-picker";
import { GSectionPrototype } from "./landing-a/prototype-g-section";
import { SoftwareApplicationJsonLd } from "./landing-a/software-application-json-ld";
import { dailyGuideExample } from "./daily-guide/daily-guide-example";
import { WeeksFigure } from "./daily-guide/weeks-figure";

// LP の版 a。並びと見た目は #594 の解決コメントの1〜11（https://github.com/gn-t-k/nu-tori/issues/594#issuecomment-6306406922）と、その試作の版8。
// 文は試作の文を下書きにした仮の文で、本番の文言は仕様3「App Store の掲載と提出」の PR で掲載情報とまとめて書く（#597 の解決コメントの1）。
// 手順の絵は、仕様3のスクリーンショットの仕組みの画像ができたら足す（手順には、画像が入るまで場所取り（lp-shot）を置いてある）。iPhone の絵は自分で描かない。
// LP_VARIANTS（wrangler.jsonc）に "a" を入れるまで、外からは見えない
export const landingAPage = createLandingVariantPage({
  variant: "a",
  listing: appStoreListing,
  ...landingPageHead,
  Content: ({ appStoreUrl }) => {
    const curry = examplePhotoMeals.find(({ key }) => key === "curry");
    if (curry === undefined) {
      throw new Error("撮るだけの節と昼ごはんの日の見本のカレーライスが、見本の食事に無い");
    }
    const ochazuke = exampleTextMeals.find(({ key }) => key === "ochazuke");
    if (ochazuke === undefined) {
      throw new Error("撮るだけの節の見本のお茶漬けが、書いた食事の見本に無い");
    }
    // 目安の節の図は出し方のページの見本の人なので、説明の数も同じ書き出しから取る
    const exampleLossKg = Math.round(
      dailyGuideExample.initial.startingWeightTrendKg - dailyGuideExample.person.targetWeightKg,
    );
    const forgottenMealText = "朝はお茶漬けを食べた";
    return (
      <div class="lp">
        <section class="lp-band lp-hero">
          <div class="lp-wrap">
            <h1>
              続けるほど、
              <wbr />
              あなたにちょうどいい
              <wbr />
              食事の量が
              <wbr />
              分かります。
            </h1>
            <p class="lp-lead">することは、体重を量ることと食べる前に写真を1枚撮ることだけです。</p>
            <div class="lp-actions">
              <AppStoreBadge href={appStoreUrl} />
              <p class="lp-secondary">30日間、支払いの登録なしで、すべての機能を使えます。</p>
            </div>
            <ol class="lp-steps">
              <li>
                <div class="lp-shot" aria-hidden="true" />
                <b>体重を量る</b>
                <span>ヘルスケアと同期します。アプリから入力することもできます。</span>
              </li>
              <li>
                <div class="lp-shot" aria-hidden="true" />
                <b>食べる前に撮る</b>
                <span>撮り忘れたら「{forgottenMealText}」と書けばOKです。</span>
              </li>
              <li>
                <div class="lp-shot" aria-hidden="true" />
                <b>目安が合っていく</b>
                <span>体重の動きと食べた量から、1日の量を毎週計算し直します。</span>
              </li>
            </ol>
          </div>
        </section>

        <section class="lp-band lp-band-surface">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>撮って送るだけ。撮り忘れたら、書いて送るだけ</h2>
              <p>
                写真を送ると、料理と材料と量を読み取って栄養を出します。撮り忘れたら、「
                {forgottenMealText}」と書いて送れば、同じように記録されます。
              </p>
            </div>
            {/* 昼に撮って送ったあと、朝の記録を忘れていたのに気づいて書いて送った、アプリの画面の下のほう */}
            <div class="lp-plate app-timeline">
              <div class="app-own">
                <span class="app-own-time">12:30</span>
                <AppMealCard entry={{ kind: "photo", meal: curry }} />
              </div>
              <div class="app-own">
                <span class="app-own-time">12:42</span>
                <AppTextMeal text={forgottenMealText} meal={ochazuke} eatenTime="7:30" />
              </div>
              <AppComposer />
            </div>
          </div>
        </section>

        <section class="lp-band">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>撮ったら、あとはまかせて閉じられます</h2>
              <p>地下の店で昼ごはんを食べた日の、アプリの動きです。</p>
            </div>
            <div>
              <LunchDay meal={curry} />
              <p class="lp-day-sum">
                記録のために
                <wbr />
                アプリを開いていたのは、
                <wbr />
                {/* 時刻と「の」のあいだで折り返さない */}
                12:30&nbsp;の数秒だけです。
              </p>
            </div>
          </div>
        </section>

        <section class="lp-band lp-band-surface">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>
                栄養は、
                <wbr />
                材料ごとに
                <wbr />
                日本食品標準成分表
                <wbr />
                から
              </h2>
              {/* 見積もるのは何がどれだけかだけで、値は成分表から取り、合計は決まった式で出す（server/src/estimation/durable-object/create-estimation-provider/match-ingredients.ts） */}
              <ol class="lp-method">
                <li>
                  <b>料理と材料と量を見積もる</b>
                  <span>写真から、料理と、その材料とグラム数を見積もります。</span>
                </li>
                <li>
                  <b>材料を成分表の食品に合わせる</b>
                  <span>
                    材料ごとに、文部科学省の日本食品標準成分表（八訂）増補2023年から近い食品を選びます。
                  </span>
                </li>
                <li>
                  <b>量をかけて足す</b>
                  <span>
                    100&nbsp;g あたりの値に量をかけて、合計を出します。量を直せば、計算し直します。
                  </span>
                </li>
              </ol>
              <p class="lp-fine">
                パッケージの栄養成分表示が写っていれば、その表示を使います。成分表に近い食品が無い材料は、値を見積もります。
              </p>
              <p>写真を選ぶと、材料と量と、値の出どころが見られます。</p>
            </div>
            <div class="lp-plate">
              <MealPhotoPicker />
            </div>
          </div>
        </section>

        <section class="lp-band">
          <div class="lp-wrap lp-feature">
            <div>
              {/* 「1日の目安」は GLOSSARY の語で、アプリの画面の名前を見せるときだけ使う（docs/agents/marketing.md）ので、見出しと手順では言い換える */}
              <h2>
                食べる量の目安は、
                <wbr />
                毎週の体重で決め直します
              </h2>
              <p>最初の目安がずれていても、記録するほど合っていきます。</p>
              <ol class="lp-method">
                <li>
                  <b>最初の目安を出す</b>
                  <span>
                    ヘルスケアに直前の28日の食べた量と体重があれば、そこから逆算します。無ければ、身長・年齢・性別と活動量から出します。
                  </span>
                </li>
                <li>
                  <b>毎週、消費カロリーを推定し直す</b>
                  <span>
                    その週に食べた量と体重の動きから推定し直します。アプリでは「推定消費カロリー」と呼びます。
                  </span>
                </li>
                <li>
                  <b>目安を決め直す</b>
                  <span>
                    推定し直した消費カロリーと目標から次の週の目安を出し、変わったら知らせます。
                  </span>
                </li>
              </ol>
            </div>
            <WeeksFigure
              labels={{
                description:
                  "推定した消費カロリーが毎週の体重で実際の消費カロリーに寄っていき、そこから目標に向けて減らす分を引いた食べる量の目安も下がる",
                estimate: ["推定した", "消費カロリー"],
                guide: ["食べる量", "の目安"],
                truth: "実際の消費カロリー",
                emphasized: "guide",
                gap: ["目標に向けて", "減らす分"],
              }}
              caption={
                <>
                  {dailyGuideExample.person.goalWeeks}週間で{exampleLossKg}&nbsp;kg
                  減量する目標を立てた場合の最初の5週間です。最初は消費カロリーを実際の消費カロリーより高く推定してしまいましたが、週を追うごとに実際の消費カロリーに近い値を推定できるようになります。
                </>
              }
            />
          </div>
        </section>

        <GSectionPrototype appStoreUrl={appStoreUrl} />
        <SoftwareApplicationJsonLd />
        <script src="/landing-a.js" defer />
        <script src="/prototype-switcher.js" defer />
      </div>
    );
  },
});
