import type { Child } from "hono/jsx";

// 1つの告知。src/announcements/<出した日>-<英小文字の名前>.tsx に1つずつ置き、announcement の名前で出す。問い合わせ先は告知のページが足す
// 公表には特定の個人が分かることを書かない（docs/agents/production-incidents.md）
export type Announcement = {
  // 出した日（YYYY-MM-DD）。告知のページはこの新しい順に並べる
  publishedOn: `${number}-${number}-${number}`;
  title: string;
  whatHappened: Child;
  impact: Child;
  whatYouCanDo: Child;
};
