import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import type { RecordId } from "../../domain/record-id";
import type { TermsAgreementStore } from "./terms-agreement-store";
import { isTermsVersion } from "./terms-versions";

// 同意のシートでの同意。要求の ID を同意の ID にし、同じ ID の再送は書かずに受け付ける
export const agreeToTerms = (
  store: Pick<TermsAgreementStore, "exists" | "insert">,
  request: { requestId: RecordId; termsVersion: string },
  agreedAt: Date,
): R.Result<void, TermsVersionUnknownError> => {
  const { requestId, termsVersion } = request;
  if (!isTermsVersion(termsVersion)) {
    return R.fail(new TermsVersionUnknownError());
  }
  if (!store.exists(requestId)) {
    store.insert({ id: requestId, termsVersion, agreementScreen: "agreement_sheet", agreedAt });
  }
  return R.succeed();
};

// 端末は今の版か、それより前に出した版しか送らないので、不具合のときだけ起きる
export class TermsVersionUnknownError extends ErrorFactory({
  name: "TermsVersionUnknownError",
  message: "知らない規約の版に同意しようとした",
}) {}
