import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { addDays } from "../../../domain/add-days";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// アカウントを作った日を置き直し、無料体験の最後の日を lastDay（YYYY-MM-DD）にする。
// 課金を入れた日（テストでは 2026-01-01）より後に作った形にするので、lastDay は 2026-01-30 より後の日を渡す
export const placeFreeTrialLastDay = (accountId: string, lastDay: string) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    state.storage.sql.exec("UPDATE first_sign_ins SET started_on = ?", addDays(lastDay, -29));
  });
