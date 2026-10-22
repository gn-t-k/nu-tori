import type { Child } from "hono/jsx";

// 1つの告知。足し方は site/AGENTS.md の「告知を足す」
export type Announcement = {
  // 出した日（YYYY-MM-DD）。告知のページはこの新しい順に並べる
  publishedOn: `${number}-${number}-${number}`;
  title: string;
  whatHappened: Child;
  impact: Child;
  whatYouCanDo: Child;
};
