import { readRows } from "./read-rows";

// 控えだけを指す修正の表。今の値は受け取った順（変更の並びとのつなぎの通し番号）で選ぶので、
// 修正の行を applied でない決定の commit で書くと、その行は並びから落ちる。修正の表を足したら、ここに足す
const correctionTables = [
  "meal_eaten_at_corrections",
  "dish_name_corrections",
  "dish_quantity_corrections",
  "ingredient_quantity_corrections",
] as const;

// 修正の表ごとに、控えに受け取った順（変更の並びとのつなぎ）がある行と、無い行を数える
export const countCorrectionsByReceivedOrder = async (
  accountId: string,
): Promise<Record<string, { withOrder: number; withoutOrder: number }>> =>
  Object.fromEntries(
    await Promise.all(
      correctionTables.map(async (table) => {
        const [counts] = await readRows(
          accountId,
          `SELECT
             COUNT(link.sync_write_receipt_id) AS withOrder,
             COUNT(*) - COUNT(link.sync_write_receipt_id) AS withoutOrder
           FROM ${table} AS correction
           LEFT JOIN sync_write_record_changes AS link
             ON link.sync_write_receipt_id = correction.sync_write_receipt_id`,
        );
        return [
          table,
          {
            withOrder: Number(counts?.["withOrder"]),
            withoutOrder: Number(counts?.["withoutOrder"]),
          },
        ];
      }),
    ),
  );
