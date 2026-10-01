// 試みの結果。提供元のエラーの種類は、提供元のエラーと 400 のときだけ持つ
export type EstimationAttemptConclusion =
  | { result: "succeeded" }
  | { result: "timed_out" | "invalid_response" }
  | { result: "provider_error" | "bad_request"; errorType: string };
