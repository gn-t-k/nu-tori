import { ErrorFactory } from "@praha/error-factory";

export class LlmCallTimedOutError extends ErrorFactory({
  name: "LlmCallTimedOutError",
  message: "提供元の呼び出しが時間の上限を超えた",
}) {}
