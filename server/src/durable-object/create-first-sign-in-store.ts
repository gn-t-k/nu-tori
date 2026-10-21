import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { FirstSignInStore } from "../domain/record-first-sign-in";
import { subscriptionTables } from "../subscription/durable-object/subscription-tables";
import { firstSignInTables } from "./first-sign-in-tables";

const { firstSignIns } = firstSignInTables;
const { freeTrialExclusions } = subscriptionTables;

export const createFirstSignInStore = (db: DrizzleSqliteDODatabase): FirstSignInStore => ({
  exists: () => db.select({ id: firstSignIns.id }).from(firstSignIns).limit(1).all().length > 0,
  findStartedOn: () =>
    db.select({ startedOn: firstSignIns.startedOn }).from(firstSignIns).get()?.startedOn,
  findTimeZone: () =>
    db.select({ timeZone: firstSignIns.timeZone }).from(firstSignIns).get()?.timeZone ?? undefined,
  insert: ({ id, startedOn, signedInAt, timeZone }) => {
    db.insert(firstSignIns)
      .values({ id, startedOn, signedInAt, timeZone: timeZone ?? null })
      .run();
  },
  excludeFreeTrial: (firstSignInId) => {
    db.insert(freeTrialExclusions).values({ firstSignInId }).run();
  },
});
