import { getTableConfig, type SQLiteTable } from "drizzle-orm/sqlite-core";

// `SELECT name, type, "notnull", pk FROM pragma_table_info(...)` の1行
export type ActualColumn = { name: string; type: string; notnull: number; pk: number };

// 移行を当てた DB の実際の列と、Drizzle の表の宣言を比べ、ずれの説明を返す（ずれが無ければ空）。
// Durable Object と D1 の両方の宣言と移行のずれのテストが使う（ADR-0021）
export const findTableDeclarationMismatches = (
  table: SQLiteTable,
  actualColumns: readonly ActualColumn[],
): string[] => {
  const { name: tableName, columns, primaryKeys } = getTableConfig(table);
  // 組の主キー（primaryKey({ columns })）の列は、列の primary が立たないので、組から拾う
  const compositeKeyColumnNames = new Set(
    primaryKeys.flatMap((key) => key.columns.map((column) => column.name)),
  );
  const declared = new Map(
    columns.map((column) => [
      column.name,
      {
        type: column.getSQLType().toLowerCase(),
        // 主キーの列は、SQLite が NOT NULL と書いていなくても値を必ず持つものとして宣言している
        notNull: column.notNull || column.primary,
        primaryKey: column.primary || compositeKeyColumnNames.has(column.name),
      },
    ]),
  );
  const actual = new Map(
    actualColumns.map((column) => [
      column.name,
      {
        type: column.type.toLowerCase(),
        notNull: column.notnull === 1 || column.pk > 0,
        primaryKey: column.pk > 0,
      },
    ]),
  );

  const mismatches: string[] = [];
  for (const [name, declaredColumn] of declared) {
    const actualColumn = actual.get(name);
    if (actualColumn === undefined) {
      mismatches.push(`${tableName}.${name}: 宣言にあるが DB に無い`);
      continue;
    }
    for (const attribute of ["type", "notNull", "primaryKey"] as const) {
      if (declaredColumn[attribute] !== actualColumn[attribute]) {
        mismatches.push(
          `${tableName}.${name}: ${attribute} が違う（宣言 ${String(declaredColumn[attribute])}、DB ${String(actualColumn[attribute])}）`,
        );
      }
    }
  }
  for (const name of actual.keys()) {
    if (!declared.has(name)) {
      mismatches.push(`${tableName}.${name}: DB にあるが宣言に無い`);
    }
  }
  return mismatches;
};
