import { ErrorFactory } from "@praha/error-factory";

export class ConversationProviderTimedOutError extends ErrorFactory({
  name: "ConversationProviderTimedOutError",
  message: "提供元の呼び出しが時間の上限を超えた",
}) {}
