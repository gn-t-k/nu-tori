import type { FC } from "hono/jsx";
import { appStoreCampaignUrl } from "./app-store-campaign-url";
import type { AppStoreListing } from "./app-store-listing";
import type { SitePage } from "./site-page";

// LP の版のページ。振り分けの Worker が /_lp/<版>/ を読んで / で返すので、正規の URL はどの版も / にする。
// 版の中身には、自分の版の名前から作ったキャンペーンのリンクを渡す（バッジと最後の節の文のリンク）
export const createLandingVariantPage = ({
  variant,
  listing,
  title,
  description,
  Content,
}: {
  variant: string;
  listing: AppStoreListing;
  title: string;
  description: string;
  Content: FC<{ appStoreUrl: string }>;
}): SitePage => {
  // Cookie の値と書き出す先のパスにそのまま使うので、英小文字と数字だけにする
  if (!/^[a-z0-9]+$/u.test(variant)) {
    throw new Error(`LP の版の名前は英小文字と数字だけにする: ${variant}`);
  }
  const appStoreUrl = appStoreCampaignUrl(listing, variant);
  return {
    outputPath: `/_lp/${variant}/`,
    title,
    description,
    search: { kind: "indexed", canonicalPath: "/" },
    Content: () => <Content appStoreUrl={appStoreUrl} />,
  };
};
