import { addDays } from "../../domain/add-days";
import { acceptedDeadlineDays } from "./accepted-deadline-days";
import { countDaysInclusive } from "./count-days-inclusive";

// 開始の日がずれて期限が受け付ける幅（両端を含めて 28〜182 日）の外に出たら、受け付けるいちばん近い日に寄せる。中ならそのまま
export const moveDeadlineIntoAcceptedRange = ({
  startedOn,
  deadlineOn,
}: {
  startedOn: string;
  deadlineOn: string;
}): string => {
  const days = countDaysInclusive(startedOn, deadlineOn);
  if (days < acceptedDeadlineDays.minimum) {
    return addDays(startedOn, acceptedDeadlineDays.minimum - 1);
  }
  if (days > acceptedDeadlineDays.maximum) {
    return addDays(startedOn, acceptedDeadlineDays.maximum - 1);
  }
  return deadlineOn;
};
