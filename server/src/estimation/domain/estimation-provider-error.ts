import { ErrorFactory } from "@praha/error-factory";

// 提供元が返したエラー（400 のほか）。errorType は提供元のエラーの種類。cause に応答のエラーの内容を持たせる
export class EstimationProviderError extends ErrorFactory({
  name: "EstimationProviderError",
  message: "提供元がエラーを返した",
  fields: ErrorFactory.fields<{ errorType: string }>(),
}) {}
