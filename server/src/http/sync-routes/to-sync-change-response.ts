import { match } from "ts-pattern";
import { toAccountSettingsChangeResponse } from "../../account-settings/http/to-account-settings-change-response";
import type { SyncChange } from "../../domain/sync-change";
import {
  toWeightRecordChangeResponse,
  toWeightRecordDeletionChangeResponse,
} from "../../weight-record/http/to-weight-record-change-response";

export const toSyncChangeResponse = (change: SyncChange) =>
  match(change)
    .with({ type: "weight_record" }, ({ sequence, weightRecord }) =>
      toWeightRecordChangeResponse(sequence, weightRecord),
    )
    .with({ type: "weight_record_deletion" }, ({ sequence, recordId }) =>
      toWeightRecordDeletionChangeResponse(sequence, recordId),
    )
    .with({ type: "account_settings" }, ({ sequence, accountSettings }) =>
      toAccountSettingsChangeResponse(sequence, accountSettings),
    )
    .exhaustive();
