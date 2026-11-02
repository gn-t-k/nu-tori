// 掲載情報の文言の1欄。draft は仮の文で、残っているあいだは wizard が App Store Connect に入れる段を始めない（仕様 #853「文言の扱い」）
export type ListingCopy = { status: "draft" | "final"; text: string };
