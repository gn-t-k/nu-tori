import { openEstimationEventWrites } from "../estimation/domain/open-estimation-event-writes";
import { writeReplyEvents } from "../reply/domain/write-reply-events";
import type { RecordChangeWrites } from "./record-change-writes";
import type { RecordType } from "./record-type";
import type { LedgerStore } from "./sync-ledger/ledger-store";
import type { RecordChangeTarget } from "./sync-ledger/record-change-target";

// 記録の変化を書く入口（RecordChangeWriter）の中身。渡された帳簿の置き場と種類の置き場に書く。トランザクション、変化の順、推定と返事の流れの出来事の書き込みを受け持つ。
// 状態の変更は、返事の流れ、推定（書き込みを受け取った順）の順に足す
export const writeRecordChangesToStores = <T>(
  ledgerStore: Pick<LedgerStore<RecordType>, "transaction" | "insertRecordChange">,
  stores: Parameters<typeof openEstimationEventWrites>[0] & Parameters<typeof writeReplyEvents>[0],
  run: (writes: RecordChangeWrites) => T,
): T => {
  const addChange = (change: RecordChangeTarget<RecordType>): void => {
    ledgerStore.insertRecordChange({ ...change, writeId: undefined });
  };
  return ledgerStore.transaction(() => {
    const estimation = openEstimationEventWrites(stores, addChange);
    const result = writeReplyEvents(stores, addChange, (reply) =>
      run({ addChange, estimation: estimation.writes, reply }),
    );
    estimation.addStatusChanges();
    return result;
  });
};
