import { addDays } from "../../../domain/add-days";
import { computeStartOfWeek } from "../../../domain/compute-start-of-week";
import { daysPerWeek } from "../../../domain/days-per-week";

// まだ見直していない週を、新しい1日の目安を当てる月曜（YYYY-MM-DD）の古い順に返す。
// 最も遅い見直し（見送りを含む）の次の月曜から、無ければ最初の目標の開始の日のあとの最初の月曜から、今週の月曜まで。
// 月曜に初めて立てた目標の推定とその月曜の見直しが重ならないよう、最も遅い推定の当てる始まりの日より後の月曜だけにする
export const findUnreviewedWeekMondays = ({
  today,
  firstGoalStartedOn,
  latestReviewEffectiveOn,
  latestEstimateEffectiveOn,
}: {
  // 要求のタイムゾーンでの今日
  today: string;
  // 目標がまだ無ければ undefined
  firstGoalStartedOn: string | undefined;
  latestReviewEffectiveOn: string | undefined;
  latestEstimateEffectiveOn: string | undefined;
}): string[] => {
  if (firstGoalStartedOn === undefined) {
    return [];
  }
  const thisMonday = computeStartOfWeek(today);
  const mondays: string[] = [];
  for (
    let monday = addDays(
      computeStartOfWeek(latestReviewEffectiveOn ?? firstGoalStartedOn),
      daysPerWeek,
    );
    monday <= thisMonday;
    monday = addDays(monday, daysPerWeek)
  ) {
    if (latestEstimateEffectiveOn === undefined || latestEstimateEffectiveOn < monday) {
      mondays.push(monday);
    }
  }
  return mondays;
};
