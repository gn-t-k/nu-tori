// 試み（①②で1回）の結果。結果の無い試みは、途中で止まった試み
export type EstimationAttemptResult =
  | "succeeded"
  | "provider_error"
  | "timed_out"
  | "bad_request"
  // 応答がドメイン層の確かめに通らない
  | "invalid_response";
