// PROTOTYPE（prototype/lp-a-g-section の枝だけに置く。main と PR #809 には入れない）
// 問い: G 節の料金（月額・年額）を、アプリの画面の台（lp-plate）に載せずにどう見せるか。
// 4案を同じページに並べ、?variant=A|B|C|D と下の切り替えの帯（/prototype-switcher.js）で1つだけ見せる
import { formatYen } from "../../format-yen";
import { subscriptionPrices } from "../../subscription-prices";

const monthly = formatYen(subscriptionPrices.monthlyYen);
const yearly = formatYen(subscriptionPrices.yearlyYen);

const Body = () => (
  <>
    <h2>30日の無料体験と料金</h2>
    <p>
      アカウントを作ってから30日、支払いの登録なしで、すべての機能を使えます。終わっても、自動でサブスクリプションにはなりません。続けたいときにだけ、月額か年額を選びます。
    </p>
  </>
);

const Closing = ({ appStoreUrl }: { appStoreUrl: string }) => (
  <p class="lp-wrap lp-closing">
    <a href={appStoreUrl}>App Store で nu-tori を見る</a>
  </p>
);

export const GSectionPrototype = ({ appStoreUrl }: { appStoreUrl: string }) => (
  <>
    <section class="lp-band lp-band-surface" data-proto-variant="A" data-proto-name="札を帯に直接置く">
      <div class="lp-wrap lp-feature">
        <div>
          <Body />
        </div>
        <div class="lp-prices">
          <p class="lp-price proto-g-tile">
            <span class="lp-secondary">月額</span>
            <b>{monthly}</b>
            <span class="lp-secondary">税込</span>
          </p>
          <p class="lp-price proto-g-tile">
            <span class="lp-secondary">年額</span>
            <b>{yearly}</b>
            <span class="lp-secondary">税込</span>
          </p>
        </div>
      </div>
      <Closing appStoreUrl={appStoreUrl} />
    </section>

    <section class="lp-band lp-band-surface" data-proto-variant="B" data-proto-name="線で区切った表" hidden>
      <div class="lp-wrap lp-feature">
        <div>
          <Body />
        </div>
        <dl class="proto-g-table">
          <div>
            <dt>月額</dt>
            <dd>
              <b>{monthly}</b>
              <span class="lp-secondary">税込</span>
            </dd>
          </div>
          <div>
            <dt>年額</dt>
            <dd>
              <b>{yearly}</b>
              <span class="lp-secondary">税込</span>
            </dd>
          </div>
        </dl>
      </div>
      <Closing appStoreUrl={appStoreUrl} />
    </section>

    <section class="lp-band lp-band-surface" data-proto-variant="C" data-proto-name="本文の中に書く" hidden>
      <div class="lp-wrap proto-g-single">
        <Body />
        <p class="proto-g-inline">
          月額&nbsp;<b>{monthly}</b>
          <span class="proto-g-dot">・</span>
          年額&nbsp;<b>{yearly}</b>
          <span class="lp-secondary lp-nowrap">（どちらも税込）</span>
        </p>
      </div>
      <Closing appStoreUrl={appStoreUrl} />
    </section>

    <section class="lp-band lp-band-surface" data-proto-variant="D" data-proto-name="30日の流れに置く" hidden>
      <div class="lp-wrap lp-feature">
        <div>
          <Body />
        </div>
        <ol class="proto-g-flow">
          <li>
            <span class="lp-secondary">1日目</span>
            <b>アカウントを作る</b>
            <span>支払いの登録なしで、すべての機能を使えます。</span>
          </li>
          <li>
            <span class="lp-secondary">30日目</span>
            <b>無料体験が終わる</b>
            <span>自動でサブスクリプションにはなりません。</span>
          </li>
          <li>
            <span class="lp-secondary">続けたいときだけ</span>
            <b>月額か年額を選ぶ</b>
            <span>
              月額&nbsp;{monthly}、年額&nbsp;{yearly}（税込）
            </span>
          </li>
        </ol>
      </div>
      <Closing appStoreUrl={appStoreUrl} />
    </section>
  </>
);
