import { ErrorFactory } from "@praha/error-factory";
import type { TokenUsage } from "../../estimation/domain/estimation-provider";

// 応答を決めた形に読めなかった（出力の上限で切れたなど）。使ったトークンは数える
export class ConversationProviderInvalidResponseError extends ErrorFactory({
  name: "ConversationProviderInvalidResponseError",
  message: "提供元の応答を読めなかった",
  fields: ErrorFactory.fields<{ usage: TokenUsage }>(),
}) {}
