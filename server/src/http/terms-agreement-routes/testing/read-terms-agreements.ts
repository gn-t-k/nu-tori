import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 残した同意を、残した順に読む
export const readTermsAgreements = (accountId: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) =>
    state.storage.sql
      .exec(
        "SELECT id, terms_version, agreement_screen, agreed_at FROM terms_agreements ORDER BY rowid",
      )
      .toArray(),
  );
