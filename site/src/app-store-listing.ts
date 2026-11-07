// どちらも公開してよい値。提供者のトークンは、配信のあと App Store Connect のキャンペーンのリンクから取った（#653）
export const appStoreListing: AppStoreListing = { appId: "6816842705", providerToken: "128288724" };

export type AppStoreListing = {
  appId: string;
  providerToken: string;
};
