import type { TermsAgreementStore } from "./terms-agreement-store";
import {
  currentTermsVersion,
  type TermsVersion,
  termsVersionsSatisfyingAgreement,
} from "./terms-versions";

// 同意を取り直す版より後のどれにも同意していなければ、同意が要る。求める版はいつも今の版
export const findTermsAgreementRequirement = (
  store: Pick<TermsAgreementStore, "hasAgreedToAnyOf">,
): { agreementRequired: boolean; termsVersion: TermsVersion } => ({
  agreementRequired: !store.hasAgreedToAnyOf(termsVersionsSatisfyingAgreement),
  termsVersion: currentTermsVersion,
});
