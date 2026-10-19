import type { DailyGuideMainReason } from "../../daily-guide/domain/daily-guide";
import type { RecordId } from "../../domain/record-id";
import type { ExpenditureDeviationDirection } from "../../expenditure-estimate/domain/expenditure-estimate";
import type { WeeklyReview, WeeklyReviewDeferral } from "./weekly-review";

export type WeeklyReviewStore = {
  find: (id: RecordId) => WeeklyReview | undefined;
  // 新しい1日の目安を当てる月曜が最も遅い見直し（見送りを含む）。まだ1週も見直していなければ無い
  findLatest: () => WeeklyReview | undefined;
  // 見直した週（見送りを含む）の、見送ったか、見直せた週のずれの向き。当てる月曜の新しい順に
  findDeviationHistory: () => (
    | { type: "deferred" }
    | { type: "reviewed"; deviationDirection: ExpenditureDeviationDirection }
  )[];
  // 行を書くのは、週の見直しを書く口（writeWeeklyReview）だけにする。表をまたぐ決まりは口が確かめる
  insert: (review: Omit<WeeklyReview, "outcome">) => void;
  insertDeferral: (
    deferral: Omit<WeeklyReviewDeferral, "type"> & { weeklyReviewId: RecordId },
  ) => void;
  insertReviewedExpenditureEstimate: (reviewed: {
    expenditureEstimateId: RecordId;
    weeklyReviewId: RecordId;
    deviationDirection: ExpenditureDeviationDirection;
  }) => void;
  insertReviewedDailyGuide: (reviewed: {
    dailyGuideId: RecordId;
    mainReason: DailyGuideMainReason;
  }) => void;
};
