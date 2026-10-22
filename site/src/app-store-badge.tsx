import { useContext } from "hono/jsx";
import { AppStoreBadgePlacement } from "./app-store-badge-placement";

// Apple の配る日本語の「App Store からダウンロード」のバッジ（public/app-store-badge.svg）を、手を加えずに置く。
// 高さ 40px、周りに高さの 1/4 の余白、動かさない、1ページに1つ（#594 の13。見た目は public/site.css）
export const AppStoreBadge = ({ href }: { href: string }) => {
  const placement = useContext(AppStoreBadgePlacement);
  if (placement === undefined) {
    throw new Error("バッジは外枠（SiteLayout）の中に置く");
  }
  if (placement.placed) {
    throw new Error("バッジは1ページに1つだけ置く");
  }
  placement.placed = true;
  return (
    <a class="app-store-badge" href={href}>
      <img src="/app-store-badge.svg" alt="App Store からダウンロード" width="109" height="40" />
    </a>
  );
};
