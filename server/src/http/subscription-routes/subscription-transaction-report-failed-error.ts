import { ErrorFactory } from "@praha/error-factory";

// Sentry に送る、断った取引の知らせ（#647 の「観測」）。どの断り方も、端末かサーバーの不具合のときだけ起きる。
// 署名つきの取引・購入者のトークン・Apple の sub を持たせないよう、応答の code だけを持ち、cause も付けない
export class SubscriptionTransactionReportFailedError extends ErrorFactory({
  name: "SubscriptionTransactionReportFailedError",
  message: "取引の知らせを断った",
  fields: ErrorFactory.fields<{
    code: "transaction_unverified" | "environment_unsupported" | "product_unknown";
  }>(),
}) {}
