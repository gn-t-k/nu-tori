import { ErrorFactory } from "@praha/error-factory";
import type { TokenUsage } from "./estimation-provider";

// 応答を決めた形に読めなかった（構造化出力が途中で切れたなど）。使ったトークンは数える
export class EstimationProviderInvalidResponseError extends ErrorFactory({
  name: "EstimationProviderInvalidResponseError",
  message: "提供元の応答を読めなかった",
  fields: ErrorFactory.fields<{ usage: TokenUsage }>(),
}) {}
