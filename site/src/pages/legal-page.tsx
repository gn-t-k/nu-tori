import { formatYen } from "../format-yen";
import type { SitePage } from "../site-page";
import { subscriptionPrices } from "../subscription-prices";
import { supportContact } from "../support-contact";

// 事項と中身の正本は #593 の解決コメント（https://github.com/gn-t-k/nu-tori/issues/593#issuecomment-6257220570）。
// 住所と電話番号の値は、請求のたびにメールで知らせ、ここにもリポジトリ・Issue・PR にも書かない（docs/agents/privacy.md）
export const legalPage: SitePage = {
  outputPath: "/legal",
  title: "特定商取引法に基づく表記 | nu-tori",
  description:
    "nu-tori のサブスクリプションについて、販売事業者、価格、支払いの時期と方法、自動更新と解約、無料体験を定めた特定商取引法に基づく表記です。",
  kind: "public",
  footerLabel: "特定商取引法に基づく表記",
  Content: () => (
    <>
      <h1>特定商取引法に基づく表記</h1>
      <div class="table-wrap">
        <table class="legal-table">
          <tbody>
            <tr>
              <th scope="row">販売事業者</th>
              <td>村上玄徳</td>
            </tr>
            <tr>
              <th scope="row">運営責任者</th>
              <td>村上玄徳</td>
            </tr>
            <tr>
              <th scope="row">住所・電話番号</th>
              <td>
                ご請求があれば、遅滞なくメールでお知らせします。
                <a href={`mailto:${supportContact.email}`}>{supportContact.email}</a>
                にご請求ください。
              </td>
            </tr>
            <tr>
              <th scope="row">メールアドレス</th>
              <td>
                <a href={`mailto:${supportContact.email}`}>{supportContact.email}</a>（
                <a href="/support">サポートのページ</a>
                の問い合わせのフォームでも受け付けます）
              </td>
            </tr>
            <tr>
              <th scope="row">販売価格</th>
              <td>
                <p>
                  サブスクリプション（自動更新）: 月額 {formatYen(subscriptionPrices.monthlyYen)}
                  （税込）、年額 {formatYen(subscriptionPrices.yearlyYen)}（税込）
                </p>
                <p>月額を1年続けると {formatYen(subscriptionPrices.monthlyYen * 12)} です。</p>
              </td>
            </tr>
            <tr>
              <th scope="row">価格のほかにかかる費用</th>
              <td>通信料は、お客様のご負担です。</td>
            </tr>
            <tr>
              <th scope="row">支払いの時期</th>
              <td>
                買ったときに、最初の期間の代金をお支払いいただきます。以後は、期間が終わる前の24時間のうちに、次の期間の代金を自動で請求します。
              </td>
            </tr>
            <tr>
              <th scope="row">支払いの方法</th>
              <td>Apple アカウントに登録した支払い方法（App Store 経由）</td>
            </tr>
            <tr>
              <th scope="row">提供の時期</th>
              <td>購入の手続きが終わったら、すぐに使えます。</td>
            </tr>
            <tr>
              <th scope="row">自動更新</th>
              <td>解約するまで、同じ期間・同じ額で自動で更新します。</td>
            </tr>
            <tr>
              <th scope="row">解約と返金</th>
              <td>
                <p>
                  いつでも iPhone
                  の設定から解約できます。更新日の24時間前までに解約すれば、次の請求はありません。
                </p>
                <p>
                  期間の途中で解約しても、その期間の終わりまで使えます。日割りの返金はしません。返金のお申し出は、Apple
                  の手続きでお願いします（App Store で買ったものは、運営者からは返金できません）。
                </p>
              </td>
            </tr>
            <tr>
              <th scope="row">無料体験</th>
              <td>
                アカウントを作ってから30日（サブスクリプションの販売を始める前からあるアカウントは、販売を始めた日から30日）。支払いの登録は要らず、終わっても自動ではサブスクリプションになりません。
              </td>
            </tr>
            <tr>
              <th scope="row">動作環境</th>
              {/* アプリの最低の版（ios/NuTori.xcodeproj の IPHONEOS_DEPLOYMENT_TARGET）と同じにする */}
              <td>iPhone、iOS 26 以降</td>
            </tr>
          </tbody>
        </table>
      </div>
    </>
  ),
};
