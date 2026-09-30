import { drizzle } from "drizzle-orm/durable-sqlite";
import type { FirstSignInStore } from "../domain/record-first-sign-in";
import { firstSignInTables } from "./first-sign-in-tables";

const { firstSignIns } = firstSignInTables;

export const createFirstSignInStore = (storage: DurableObjectStorage): FirstSignInStore => {
  const db = drizzle(storage);
  return {
    exists: () => db.select({ id: firstSignIns.id }).from(firstSignIns).limit(1).all().length > 0,
    insert: ({ id, startedOn, signedInAt, timeZone }) => {
      db.insert(firstSignIns)
        .values({ id, startedOn, signedInAt, timeZone: timeZone ?? null })
        .run();
    },
  };
};
