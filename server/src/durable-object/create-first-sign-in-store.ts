import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { FirstSignInStore } from "../domain/record-first-sign-in";
import { firstSignInTables } from "./first-sign-in-tables";

const { firstSignIns } = firstSignInTables;

export const createFirstSignInStore = (db: DrizzleSqliteDODatabase): FirstSignInStore => ({
  exists: () => db.select({ id: firstSignIns.id }).from(firstSignIns).limit(1).all().length > 0,
  findStartedOn: () =>
    db.select({ startedOn: firstSignIns.startedOn }).from(firstSignIns).get()?.startedOn,
  insert: ({ id, startedOn, signedInAt, timeZone }) => {
    db.insert(firstSignIns)
      .values({ id, startedOn, signedInAt, timeZone: timeZone ?? null })
      .run();
  },
});
