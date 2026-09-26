export type DurableObjectMigration = {
  version: number;
  sql: string;
};

export const applyDurableObjectMigrations = (
  storage: DurableObjectStorage,
  migrations: readonly DurableObjectMigration[],
): void => {
  storage.sql.exec(
    "CREATE TABLE IF NOT EXISTS durable_object_migrations (version INTEGER PRIMARY KEY)",
  );
  const appliedVersion = readAppliedVersion(storage.sql);
  for (const migration of migrations) {
    if (migration.version <= appliedVersion) {
      continue;
    }
    storage.transactionSync(() => {
      storage.sql.exec(migration.sql);
      storage.sql.exec(
        "INSERT INTO durable_object_migrations (version) VALUES (?)",
        migration.version,
      );
    });
  }
};

const readAppliedVersion = (sql: SqlStorage): number => {
  const { version } = sql
    .exec<{ version: number | null }>(
      "SELECT MAX(version) AS version FROM durable_object_migrations",
    )
    .one();
  return version ?? 0;
};
