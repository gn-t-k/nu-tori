import { drizzle } from "drizzle-orm/durable-sqlite";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import { writeRecordChangesToStores } from "../../domain/write-record-changes-to-stores";
import { createEventWriteStores } from "../create-event-write-stores";
import { createLedgerStore } from "../create-ledger-store";

// 記録の変化を書く入口を、Durable Object の置き場で組む
export const createRecordChangeWriter = (storage: DurableObjectStorage): RecordChangeWriter => {
  const ledgerStore = createLedgerStore(storage);
  const stores = createEventWriteStores(drizzle(storage));
  return (run) => writeRecordChangesToStores(ledgerStore, stores, run);
};
