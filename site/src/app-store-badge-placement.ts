import { createContext } from "hono/jsx";

// 外枠（site-layout.tsx）がページごとに作り、バッジ（app-store-badge.tsx）が置いた印を付け、そのあとに書き出す足が読んで Apple の商標の行を出す。
// hono/jsx は文書の順に書き出すので、main の中のバッジが足より先に印を付ける
export const AppStoreBadgePlacement = createContext<{ placed: boolean } | undefined>(undefined);
