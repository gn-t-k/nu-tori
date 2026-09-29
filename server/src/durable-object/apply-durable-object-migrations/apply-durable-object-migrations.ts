export type DurableObjectMigration = {
  version: number;
  sql: string;
};

// 当てた版の最大値ではなく、当てた版の集合で判断する。並んだ PR の移行が、版の大きいほうから main に入ることがあるため
export const applyDurableObjectMigrations = (
  storage: DurableObjectStorage,
  migrations: readonly DurableObjectMigration[],
): void => {
  assertVersionsUnique(migrations);
  storage.sql.exec(
    "CREATE TABLE IF NOT EXISTS durable_object_migrations (version INTEGER PRIMARY KEY)",
  );
  const appliedVersions = readAppliedVersions(storage.sql);
  const pendingMigrations = migrations
    .filter((migration) => !appliedVersions.has(migration.version))
    .toSorted((a, b) => a.version - b.version);
  for (const migration of pendingMigrations) {
    storage.transactionSync(() => {
      storage.sql.exec(migration.sql);
      storage.sql.exec(
        "INSERT INTO durable_object_migrations (version) VALUES (?)",
        migration.version,
      );
    });
  }
};

const assertVersionsUnique = (migrations: readonly DurableObjectMigration[]): void => {
  const versions = new Set<number>();
  for (const { version } of migrations) {
    if (versions.has(version)) {
      throw new Error(`Durable Object の移行の版 ${version} が重複している`);
    }
    versions.add(version);
  }
};

const readAppliedVersions = (sql: SqlStorage): ReadonlySet<number> => {
  const rows = sql
    .exec<{ version: number }>("SELECT version FROM durable_object_migrations")
    .toArray();
  return new Set(rows.map(({ version }) => version));
};
