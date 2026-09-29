import type { FirstSignInStore } from "../domain/record-first-sign-in";

export const createFirstSignInStore = (sql: SqlStorage): FirstSignInStore => ({
  exists: () => sql.exec("SELECT 1 FROM first_sign_ins LIMIT 1").toArray().length > 0,
  insert: ({ id, startedOn, signedInAt, timeZone }) => {
    sql.exec(
      "INSERT INTO first_sign_ins (id, started_on, signed_in_at, time_zone) VALUES (?, ?, ?, ?)",
      id,
      startedOn,
      signedInAt.getTime(),
      timeZone ?? null,
    );
  },
});
