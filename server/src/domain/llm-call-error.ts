import { ErrorFactory } from "@praha/error-factory";

// LLM の提供元の呼び出しが失敗した（400・時間切れ・読めない応答のほか）。推定と返事（読み分けを含む）の提供元が、この1組の失敗を使う。
// errorType は提供元のエラーの種類（つなげなければ connection_error など）。cause に応答のエラーの内容を持たせる
export class LlmCallError extends ErrorFactory({
  name: "LlmCallError",
  message: "提供元の呼び出しが失敗した",
  fields: ErrorFactory.fields<{ errorType: string }>(),
}) {}
