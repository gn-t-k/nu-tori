import { eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { TermsAgreementStore } from "../domain/terms-agreement-store";
import { termsAgreementTables } from "./terms-agreement-tables";

const { termsAgreements } = termsAgreementTables;

export const createTermsAgreementStore = (db: DrizzleSqliteDODatabase): TermsAgreementStore => ({
  exists: (id) =>
    db
      .select({ id: termsAgreements.id })
      .from(termsAgreements)
      .where(eq(termsAgreements.id, id))
      .get() !== undefined,
  hasAgreedToAnyOf: (versions) =>
    db
      .select({ id: termsAgreements.id })
      .from(termsAgreements)
      .where(inArray(termsAgreements.termsVersion, [...versions]))
      .limit(1)
      .get() !== undefined,
  insert: (agreement) => {
    db.insert(termsAgreements).values(agreement).run();
  },
});
