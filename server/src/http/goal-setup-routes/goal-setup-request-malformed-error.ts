import { ErrorFactory } from "@praha/error-factory";

// 形の誤りで断った要求。値は残さないので、誤っていた場所（キーの道筋）と種類だけを持つ
export class GoalSetupRequestMalformedError extends ErrorFactory({
  name: "GoalSetupRequestMalformedError",
  message: "目標の設定の要求の形が違う",
  fields: ErrorFactory.fields<{ issues: { path: string; code: string }[] }>(),
}) {}
