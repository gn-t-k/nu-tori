import { medicalDisclaimer, type AppStoreConnectListing } from "./app-store-connect-listing";

// 掲載情報が App Store の上限と、nu-tori の決まり（仕様 #853「テストの決定」）に外れるところを、決まった順で挙げる
export const listingRuleViolations = (listing: AppStoreConnectListing): ListingRuleViolation[] => {
  const keywords = listing.keywords.split(",").map((keyword) => keyword.trim().toLowerCase());
  const nameAndSubtitle = `${listing.name}\n${listing.subtitle.text}`.toLowerCase();
  const description = listing.description.text;
  const checks: readonly [ListingRuleViolation, boolean][] = [
    ["name-too-long", characterCount(listing.name) > 30],
    ["subtitle-too-long", characterCount(listing.subtitle.text) > 30],
    ["promotional-text-too-long", characterCount(listing.promotionalText.text) > 170],
    ["description-too-long", characterCount(description) > 4000],
    // ヘルプは 100 bytes、search と product-page は 100 characters と食い違うので、狭いバイトで数える（#597 の「確かめた事実」）
    ["keywords-too-long", new TextEncoder().encode(listing.keywords).length > 100],
    // 名前とサブタイトルの語は、キーワード欄で繰り返しても検索に効かない（https://developer.apple.com/app-store/search/）
    ["keyword-in-name-or-subtitle", keywords.some((keyword) => nameAndSubtitle.includes(keyword))],
    ["duplicate-keyword", new Set(keywords).size !== keywords.length],
    // 説明文とスクリーンショットに価格を載せない（App Review Guidelines 2.3.7・2.3.14、product-page）
    ["price-in-description", hasPrice(description)],
    [
      "price-in-screenshot-headline",
      listing.screenshots.some(({ headline }) => hasPrice(headline.text)),
    ],
    // 自動更新のサブスクリプションは、利用規約とプライバシーポリシーへのリンクを載せる（3.1.2）
    ["terms-url-missing", !description.includes(listing.urls.terms)],
    ["privacy-policy-url-missing", !description.includes(listing.urls.privacyPolicy)],
    // 医療の助言ではないことを書く（1.4.1、#592 の3）
    ["medical-disclaimer-missing", !description.includes(medicalDisclaimer)],
  ];
  return checks.filter(([, violated]) => violated).map(([violation]) => violation);
};

export type ListingRuleViolation =
  | "name-too-long"
  | "subtitle-too-long"
  | "promotional-text-too-long"
  | "description-too-long"
  | "keywords-too-long"
  | "keyword-in-name-or-subtitle"
  | "duplicate-keyword"
  | "price-in-description"
  | "price-in-screenshot-headline"
  | "terms-url-missing"
  | "privacy-policy-url-missing"
  | "medical-disclaimer-missing";

// 字は UTF-16 の単位でなく、見た目の1字（書記素）で数える
const characterCount = (text: string) =>
  [...new Intl.Segmenter("ja", { granularity: "grapheme" }).segment(text)].length;

const hasPrice = (text: string) => /[0-9０-９][0-9０-９,，]*\s*円/u.test(text);
