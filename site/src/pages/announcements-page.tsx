import type { Announcement } from "../announcement";
import type { SitePage } from "../site-page";

// アプリが開けない障害のときにも読めるよう、告知を nu-tori.app に載せる
export const announcementsPage: SitePage = {
  outputPath: "/announcements",
  title: "告知 | nu-tori",
  description:
    "nu-tori の障害や個人情報の取り扱いなど、運営からの告知を新しい順に載せています。アプリが開けないときもここで読めます。",
  kind: "public",
  footerLabel: "告知",
  Content: () => {
    const announcements = sortNewestFirst(
      import.meta.glob<Announcement>("../announcements/*.tsx", {
        eager: true,
        import: "announcement",
      }),
    );
    return (
      <>
        <h1>告知</h1>
        {announcements.length === 0 ? (
          <p>今お知らせしていることはありません。</p>
        ) : (
          announcements.map((announcement) => (
            <article>
              <h2>{announcement.title}</h2>
              <p class="dates">{formatPublishedOn(announcement.publishedOn)}</p>
              <h3>何が起きたか</h3>
              {announcement.whatHappened}
              <h3>影響</h3>
              {announcement.impact}
              <h3>できること</h3>
              {announcement.whatYouCanDo}
            </article>
          ))
        )}
        <h2>問い合わせ先</h2>
        <p>
          告知についての問い合わせは、<a href="/support">サポート</a>
          のページの問い合わせのフォームかメールで受け付けます。
        </p>
      </>
    );
  },
};

// 同じ日に出した告知は、ファイル名の後ろのものを先にする
const sortNewestFirst = (modules: Record<string, Announcement>): Announcement[] =>
  Object.entries(modules)
    .toSorted(
      ([leftPath, left], [rightPath, right]) =>
        right.publishedOn.localeCompare(left.publishedOn) || rightPath.localeCompare(leftPath),
    )
    .map(([, announcement]) => announcement);

const formatPublishedOn = (publishedOn: Announcement["publishedOn"]): string => {
  const [year, month, day] = publishedOn.split("-").map(Number);
  return `${year}年${month}月${day}日`;
};
