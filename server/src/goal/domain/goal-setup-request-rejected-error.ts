import { ErrorFactory } from "@praha/error-factory";

// 目標の設定の要求を断った。不具合のときだけ届くので、受け口が Sentry に送る。身体データと摂取エネルギーと体重の値は持たせない
export class GoalSetupRequestRejectedError extends ErrorFactory({
  name: "GoalSetupRequestRejectedError",
  message: ({ reason }) => `目標の設定の要求を断った: ${reason}`,
  fields: ErrorFactory.fields<{ reason: GoalSetupRequestRejectionReason }>(),
}) {}

export type GoalSetupRequestRejectionReason =
  | "invalid_time_zone"
  | "body_data_out_of_range"
  | "deadline_out_of_range"
  // 体重記録が1つも無く、開始の日の体重の傾向が無い
  | "weight_record_missing"
  // 逆算できず、式に使う身体データ（歩いた日のある歩数か、活動量の3択を含む）も無い
  | "body_data_missing";
