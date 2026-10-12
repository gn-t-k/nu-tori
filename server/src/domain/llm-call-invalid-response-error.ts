import { ErrorFactory } from "@praha/error-factory";
import type { TokenUsage } from "./token-usage";

// 応答を決めた形に読めなかった（構造化出力が出力の上限で切れたなど）。使ったトークンは数える
export class LlmCallInvalidResponseError extends ErrorFactory({
  name: "LlmCallInvalidResponseError",
  message: "提供元の応答を読めなかった",
  fields: ErrorFactory.fields<{ usage: TokenUsage }>(),
}) {}
