import { ErrorFactory } from "@praha/error-factory";

// 提供元の呼び出しが失敗した。errorType は提供元のエラーの種類（つなげなければ connection_error など）。
// cause に応答のエラーの内容を持たせる
export class ConversationProviderError extends ErrorFactory({
  name: "ConversationProviderError",
  message: "提供元の呼び出しが失敗した",
  fields: ErrorFactory.fields<{ errorType: string }>(),
}) {}
