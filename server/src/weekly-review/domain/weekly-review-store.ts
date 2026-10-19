import type { RecordId } from "../../domain/record-id";
import type { WeeklyReview, WeeklyReviewDeferral } from "./weekly-review";

export type WeeklyReviewStore = {
  find: (id: RecordId) => WeeklyReview | undefined;
  // 新しい1日の目安を当てる月曜が最も遅い見直し（見送りを含む）。まだ1週も見直していなければ無い
  findLatest: () => WeeklyReview | undefined;
  // 行を書くのは、週の見直しを書く口（writeWeeklyReview）だけにする。表をまたぐ決まりは口が確かめる
  insert: (review: Omit<WeeklyReview, "outcome">) => void;
  insertDeferral: (
    deferral: Omit<WeeklyReviewDeferral, "type"> & { weeklyReviewId: RecordId },
  ) => void;
};
