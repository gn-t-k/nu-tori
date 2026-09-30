import { match, P } from "ts-pattern";
import { toAccountSettingsChangeResponse } from "../../account-settings/http/to-account-settings-change-response";
import type { SyncChange } from "../../domain/sync-change";
import {
  toWeightRecordChangeResponse,
  toWeightRecordDeletionChangeResponse,
} from "../../weight-record/http/to-weight-record-change-response";
import { httpRecordKinds } from "./http-record-kinds";

export const toSyncChangeResponse = (change: SyncChange) =>
  match(change)
    .with({ recordType: P.string }, ({ sequence, recordType, current }) => {
      const kind = httpRecordKinds.find(({ name }) => name === recordType);
      if (kind === undefined) {
        throw new Error(`受け口の登録簿に無い種類の変更: ${String(recordType)}`);
      }
      return kind.toChangeResponse(sequence, current);
    })
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
