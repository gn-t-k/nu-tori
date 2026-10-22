import type { RecordId } from "../../domain/record-id";
import type { TermsAgreementScreen } from "./terms-agreement-screens";
import type { TermsVersion } from "./terms-version";

export type TermsAgreementStore = {
  exists: (id: RecordId) => boolean;
  hasAgreedToAnyOf: (versions: readonly TermsVersion[]) => boolean;
  insert: (agreement: {
    id: RecordId;
    termsVersion: TermsVersion;
    agreementScreen: TermsAgreementScreen;
    agreedAt: Date;
  }) => void;
};
