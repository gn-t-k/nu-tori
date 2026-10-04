import { desc } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { LatestTimeZoneStore } from "../domain/latest-time-zone-store";
import { syncLedgerTables } from "./sync-ledger-tables";

const { syncRequestLogs } = syncLedgerTables;

export const createLatestTimeZoneStore = (db: DrizzleSqliteDODatabase): LatestTimeZoneStore => ({
  find: () =>
    db
      .select({ timeZone: syncRequestLogs.timeZone })
      .from(syncRequestLogs)
      .orderBy(desc(syncRequestLogs.receivedAt))
      .limit(1)
      .get()?.timeZone,
});
