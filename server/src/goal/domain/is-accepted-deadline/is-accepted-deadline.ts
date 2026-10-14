import { countDaysInclusive } from "../count-days-inclusive";

// 期限は、開始の日からの日数（両端を含む）が 4〜26 週に収まる日だけを受け付ける
export const isAcceptedDeadline = ({
  startDay,
  deadlineDay,
}: {
  startDay: string;
  deadlineDay: string;
}): boolean => {
  const days = countDaysInclusive(startDay, deadlineDay);
  return 28 <= days && days <= 182;
};
