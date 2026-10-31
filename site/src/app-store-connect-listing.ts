import { appStoreScreenshots, type AppStoreScreenshot } from "./app-store-screenshots.ts";
import type { ListingCopy } from "./listing-copy.ts";
import { dailyGuidePage } from "./pages/daily-guide-page";
import { privacyPage } from "./pages/privacy-page";
import { supportPage } from "./pages/support-page";
import { termsPage } from "./pages/terms-page";
import { canonicalPathOf, type SitePage } from "./site-page";
import { siteOrigin } from "./site-origin";
import { sitePages } from "./site-pages";

// App Store Connect に開発者が wizard で入れる掲載情報の正本（仕様 #853「掲載情報のモジュール」）。
// アプリの ID と提供者のトークン（app-store-listing.ts）と違い、ページには出さない。テストと合成のコマンドと wizard が読む（site/AGENTS.md「掲載情報を直す」）
// 仮の文（status: "draft"）は #597 の解決コメントの文。本番の文は #816 を読んで #862 で書く

export const medicalDisclaimer = "医療の助言ではありません。持病のある方は医師に相談してください。";

// 公開のページの URL を、ページの一覧から作る。一覧から外したページを指していたら止まる
const publicPageUrl = (page: SitePage): string => {
  const path = canonicalPathOf(page);
  if (!sitePages.includes(page) || page.kind !== "public" || path === undefined) {
    throw new Error(`公開のページの一覧に無い: ${page.outputPath}`);
  }
  return `${siteOrigin}${path}`;
};

export const appStoreConnectListing: AppStoreConnectListing = (() => {
  const urls = {
    support: publicPageUrl(supportPage),
    marketing: siteOrigin,
    privacyPolicy: publicPageUrl(privacyPage),
    terms: publicPageUrl(termsPage),
  };
  return {
    // 名前は検索の順位に効く。最初の提出のあとは新しい版でしか直せない（#597 の3）
    name: "nu-tori：写真で食事記録とカロリー計算",
    subtitle: { status: "draft", text: "操作は、朝の体重と、食べる前の1枚だけ。" },
    promotionalText: {
      status: "draft",
      text: "食事と体重の記録から、あなたに合った1日のカロリーを、毎週計算し直します。",
    },
    description: {
      status: "draft",
      // 段の並びと、料金の段の3つの事実は残す（仕様 #853「文言の扱い」）
      text: [
        "■ 撮るだけで記録",
        "食べる前に写真を1枚撮るだけで、AI が料理と量を見分けて、カロリーと PFC（たんぱく質・脂質・炭水化物）を出します。撮り忘れた食事は、食べたものを書くだけで記録できます。",
        "",
        "■ 日本食品標準成分表で数える",
        "料理の材料と量を見積もり、日本食品標準成分表の値から栄養を数えます。材料と量は、あとから直せます。",
        "",
        "■ 1日に食べる量の目安が、毎週変わる",
        "朝の体重は、Appleヘルスケアアプリと連係して読み込みます。毎週、体重の動きと食べた量から、1日に食べる量の目安を計算し直します。出し方は次のページで説明しています。",
        publicPageUrl(dailyGuidePage),
        "",
        "■ 確定を押さずに食べはじめられる",
        "撮ったら、推定を待たずに食べはじめられます。推定が終わると、記録にカロリーと栄養が並びます。",
        "",
        "■ 料金",
        "30日間、すべての機能を無料で使えます。支払いの登録は要らず、30日が過ぎても自動で課金されることはありません。続けるときは、アプリの中からサブスクリプション（自動更新・有料）を始めてください。いつでも解約できます。",
        "",
        "■ ご注意",
        medicalDisclaimer,
        "",
        `利用規約: ${urls.terms}`,
        `プライバシーポリシー: ${urls.privacyPolicy}`,
      ].join("\n"),
    },
    // 名前・サブタイトル・カテゴリの語は入れない。サブタイトルを書き直したら、そこに入った語を抜く（#597 の5）
    keywords: "食事管理,PFC,体重管理,ダイエット,AI,にゅーとり,栄養,成分表,減量,増量",
    screenshots: appStoreScreenshots,
    // 審査の人とのやりとりは英語なので、英語で書く。会社の名前は審査へのメモには書いてよいが、掲載情報には書かない（仕様 #853「審査に出す」）
    reviewNotes: [
      "Sign-in: nu-tori uses Sign in with Apple only, so we do not provide a demo account. Please sign in with your own Apple Account. A new account starts a 30-day free trial with all features.",
      "",
      'Subscription: Open the Account tab (アカウント) and tap "サブスクリプション" at the top to reach the purchase screen. Our production server also accepts Sandbox purchases, so you can complete a purchase there.',
      "",
      "Health: nu-tori reads body weight from Health and writes the nutrition of recorded meals to Health.",
      "",
      "External services: Anthropic (Claude) estimates meals from photos and text and writes replies. Cloudflare hosts the server, the database and the photos. Sentry receives crash and error reports. PostHog receives usage statistics. None of them is used for tracking.",
      "",
      "nu-tori is not a medical device and does not give medical advice.",
    ].join("\n"),
    urls,
    // 氏名はリポジトリに書かず、wizard で開発者がこの後ろに足す（#597 の14）
    copyrightPrefix: "2026 ",
    // LP の構造化データの HealthApplication とそろえる。セカンダリは置かない
    primaryCategory: "ヘルスケア／フィットネス",
  };
})();

export type AppStoreConnectListing = {
  name: string;
  subtitle: ListingCopy;
  promotionalText: ListingCopy;
  description: ListingCopy;
  // App Store Connect の欄に入れるとおりの、「,」で区切った1行
  keywords: string;
  screenshots: readonly AppStoreScreenshot[];
  reviewNotes: string;
  // terms は App Store Connect の欄ではないが、説明文に載せる（3.1.2）
  urls: { support: string; marketing: string; privacyPolicy: string; terms: string };
  copyrightPrefix: string;
  primaryCategory: string;
};

// 仮の文が残っている欄の名前。wizard は、これが空になるまで App Store Connect に入れる段を始めない
export const draftListingFields = (listing: AppStoreConnectListing): string[] => {
  const copies: readonly { field: string; copy: ListingCopy }[] = [
    { field: "subtitle", copy: listing.subtitle },
    { field: "promotionalText", copy: listing.promotionalText },
    { field: "description", copy: listing.description },
    ...listing.screenshots.map(({ name, headline }) => ({
      field: `screenshots.${name}.headline`,
      copy: headline,
    })),
  ];
  return copies.filter(({ copy }) => copy.status === "draft").map(({ field }) => field);
};
