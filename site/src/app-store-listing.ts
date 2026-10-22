import type { AppStoreListing } from "./app-store-campaign-url";

// どちらも公開してよい値。提供者のトークンは、配信のあと App Store Connect で確かめて入れる（#653。LP_VARIANTS を ["a"] にする PR で一緒に）
export const appStoreListing: AppStoreListing = { appId: "6816842705", providerToken: undefined };
