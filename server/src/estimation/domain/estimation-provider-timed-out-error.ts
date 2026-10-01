import { ErrorFactory } from "@praha/error-factory";

export class EstimationProviderTimedOutError extends ErrorFactory({
  name: "EstimationProviderTimedOutError",
  message: "提供元の呼び出しが時間の上限を超えた",
}) {}
