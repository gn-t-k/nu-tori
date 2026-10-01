import { ErrorFactory } from "@praha/error-factory";

// HTTP 400。やり直さずに諦める（ワークスペースの月の支出の上限に当たったときも 400）。cause に応答のエラーの内容を持たせる
export class EstimationProviderBadRequestError extends ErrorFactory({
  name: "EstimationProviderBadRequestError",
  message: "提供元が要求を受け付けなかった（400）",
  fields: ErrorFactory.fields<{ errorType: string }>(),
}) {}
