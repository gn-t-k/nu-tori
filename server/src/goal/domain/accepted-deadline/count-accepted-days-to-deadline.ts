import { R } from "@praha/byethrow";
import { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import { acceptedDeadlineDays } from "./accepted-deadline-days";
import { countDaysInclusive } from "./count-days-inclusive";

// 開始の日から期限の日までの日数（両端を含む）。端末は受け付ける日だけを選ばせるので、外の期限は不具合のときだけ届く
export const countAcceptedDaysToDeadline = ({
  startedOn,
  deadlineOn,
}: {
  startedOn: string;
  deadlineOn: string;
}): R.Result<number, GoalSetupRequestRejectedError> => {
  const days = countDaysInclusive(startedOn, deadlineOn);
  return acceptedDeadlineDays.minimum <= days && days <= acceptedDeadlineDays.maximum
    ? R.succeed(days)
    : R.fail(new GoalSetupRequestRejectedError({ reason: "deadline_out_of_range" }));
};
