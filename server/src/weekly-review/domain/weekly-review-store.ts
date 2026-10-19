import type { RecordId } from "../../domain/record-id";
import type { WeeklyReview } from "./weekly-review";

// 週の見直しの置き場。行を書く口は、週の見直しを書く口と一緒に足す
export type WeeklyReviewStore = {
  find: (id: RecordId) => WeeklyReview | undefined;
};
