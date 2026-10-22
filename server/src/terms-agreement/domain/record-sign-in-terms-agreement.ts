import { generateRecordId } from "../../domain/record-id";
import type { TermsAgreementStore } from "./terms-agreement-store";
import { isTermsVersion } from "./terms-version";

// サインインの画面での同意。その版に同意した行がまだ無ければ足す。
// 版を送らない前の版のアプリと、知らない版は書かない（次に開いたとき、同意のシートで取る）。
// 知らない版でサインインを断らないのは、同意を取り損ねても同意のシートで取り直せるため
export const recordSignInTermsAgreement = (
  store: Pick<TermsAgreementStore, "hasAgreedToAnyOf" | "insert">,
  signIn: { agreedTermsVersion: string | undefined; signedInAt: Date },
): void => {
  const { agreedTermsVersion, signedInAt } = signIn;
  if (agreedTermsVersion === undefined || !isTermsVersion(agreedTermsVersion)) {
    return;
  }
  if (store.hasAgreedToAnyOf([agreedTermsVersion])) {
    return;
  }
  store.insert({
    id: generateRecordId(),
    termsVersion: agreedTermsVersion,
    agreementScreen: "sign_in",
    agreedAt: signedInAt,
  });
};
