import { AppStoreBadge } from "../app-store-badge";
import { appStoreListing } from "../app-store-listing";
import { createLandingVariantPage } from "../create-landing-variant-page";
import { formatYen } from "../format-yen";
import { landingPageHead } from "../landing-page-head";
import { subscriptionPrices } from "../subscription-prices";
import { AppTextMeal } from "./landing-a/app-text-meal";
import { AppMealCard } from "./landing-a/app-meal-card";
import { exampleMeals } from "./landing-a/example-meals";
import { FlowComparison } from "./landing-a/flow-comparison";
import { MealPhotoPicker } from "./landing-a/meal-photo-picker";
import { ReviewExample } from "./landing-a/review-example";
import { SoftwareApplicationJsonLd } from "./landing-a/software-application-json-ld";

// LP の版 a。並びと見た目は #594 の解決コメントの1〜11（https://github.com/gn-t-k/nu-tori/issues/594#issuecomment-6306406922）と、その試作の版8。
// 文は試作の文を下書きにした仮の文で、本番の文言は仕様3「App Store の掲載と提出」の PR で掲載情報とまとめて書く（#597 の解決コメントの1）。
// 手順と流れの絵は、仕様3のスクリーンショットの仕組みの画像ができたら足す（手順には、画像が入るまで場所取り（lp-shot）を置いてある）。iPhone の絵は自分で描かない。
// LP_VARIANTS（wrangler.jsonc）に "a" を入れるまで、外からは見えない
export const landingAPage = createLandingVariantPage({
  variant: "a",
  listing: appStoreListing,
  ...landingPageHead,
  Content: ({ appStoreUrl }) => {
    const curry = exampleMeals.find(({ key }) => key === "curry");
    if (curry === undefined) {
      throw new Error("撮るだけの節の見本のカレーライスが、見本の食事に無い");
    }
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
                <span>撮り忘れたら「昼にカレー」と書けばOKです。</span>
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
              <h2>撮るだけ・撮り忘れたら書くだけ</h2>
              <p>
                写真から料理と材料と量を読み取り、栄養を出します。撮り忘れた食事は、書けば入ります。
              </p>
              <p>読み取りが違っていたら、あとで直せます。</p>
            </div>
            <div class="lp-plate lp-entries">
              <div>
                <p class="lp-fine">撮ったとき</p>
                <AppMealCard meal={curry} entry={{ kind: "photo" }} />
              </div>
              <div>
                <p class="lp-fine">書いたとき</p>
                <AppTextMeal text="昼にカレー" meal={curry} eatenTime="12:00" />
              </div>
            </div>
          </div>
        </section>

        <section class="lp-band">
          <div class="lp-wrap">
            <h2>撮ったら、確定を押さずに食べはじめられます</h2>
            <p>写真を読むのは裏で進みます。候補を選んで確定する操作はありません。</p>
            <FlowComparison />
            <ol class="lp-steps lp-numbered">
              <li>
                <b>撮る</b>
                <span>食べる前に1枚撮って、そのまま閉じます。</span>
              </li>
              <li>
                <b>食べる</b>
                <span>食べているあいだに、写真から料理と材料と量を読みます。</span>
              </li>
              <li>
                <b>あとで見る・直す</b>
                <span>
                  開けば、何をどれだけと読んだかが見られます。違っていたら、そこで直せます。
                </span>
              </li>
            </ol>
          </div>
        </section>

        <section class="lp-band lp-band-surface">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>日本食品標準成分表で数えます</h2>
              <p>
                料理を材料に分け、材料ごとに文部科学省の日本食品標準成分表（八訂）増補2023年の値を引いて数えます。食事を開けば、成分表の値を使った材料の数が見られます。
              </p>
              <p class="lp-fine">
                写真に栄養成分表示が写っていれば、その表示を使います。成分表に合うものが無い材料は、値を推定します。
              </p>
              <p class="lp-fine">見本の写真は Wikimedia Commons の CC0 の写真（Ocdp）です。</p>
            </div>
            <div class="lp-plate">
              <MealPhotoPicker />
            </div>
          </div>
        </section>

        <section class="lp-band">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>1日の目安は、毎週の体重の動きで直ります</h2>
              <p>
                毎週、その週の体重の動きと食べた量から、1日に使っているカロリーを見積もり直し、1日に食べる量の目安を直します。
              </p>
              <p>
                最初の目安は、ヘルスケアに直前の28日の食べた量と体重があれば、そこから逆算します。無ければ、身長・生年月日・性別と、歩数か活動量から式で出し、使うほど記録に合っていきます。
              </p>
            </div>
            <ReviewExample />
          </div>
        </section>

        <section class="lp-band lp-band-surface">
          <div class="lp-wrap lp-feature">
            <div>
              <h2>30日の無料体験と料金</h2>
              <p>
                アカウントを作ってから30日、支払いの登録なしで、すべての機能を使えます。終わっても、自動でサブスクリプションにはなりません。続けたいときにだけ、月額か年額を選びます。
              </p>
              <p class="lp-fine">
                無料体験が終わったあとも、体重の記録と、これまでの記録の見返しはそのまま使えます。
              </p>
            </div>
            <div class="lp-plate lp-prices">
              <p class="lp-price">
                <span class="lp-secondary">月額</span>
                <b>{formatYen(subscriptionPrices.monthlyYen)}</b>
                <span class="lp-secondary">税込</span>
              </p>
              <p class="lp-price">
                <span class="lp-secondary">年額</span>
                <b>{formatYen(subscriptionPrices.yearlyYen)}</b>
                <span class="lp-secondary">税込</span>
              </p>
            </div>
          </div>
          {/* バッジは1ページに1つなので、最後は文のリンクにする（#594 の13） */}
          <p class="lp-wrap lp-closing">
            <a href={appStoreUrl}>App Store で nu-tori を見る</a>
          </p>
        </section>
        <SoftwareApplicationJsonLd />
        <script src="/landing-a.js" defer />
      </div>
    );
  },
});
