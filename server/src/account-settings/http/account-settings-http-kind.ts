import type { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { PresentRecord } from "../../domain/sync-ledger/present-record";
import type { AccountSettings } from "../domain/account-settings";
import type { updateAccountSettingsWriteSchema } from "./account-settings-write-schema";
import { toAccountSettingsChangeResponse } from "./to-account-settings-change-response";
import { toUpdateAccountSettingsWrite } from "./to-account-settings-write";

export const accountSettingsHttpKind: HttpRecordKind = {
  name: "account_settings",
  writeTypes: ["update_account_settings"],
  toWrite: (write: z.infer<typeof updateAccountSettingsWriteSchema>) =>
    toUpdateAccountSettingsWrite(write),
  toChangeResponse: (sequence, current: PresentRecord<AccountSettings>) => {
    if (current.status === "deleted") {
      throw new Error("アカウントの設定に削除の印は無い");
    }
    return toAccountSettingsChangeResponse(sequence, current.value);
  },
};
