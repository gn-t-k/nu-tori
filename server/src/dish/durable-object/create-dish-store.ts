import { and, count, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { ingredientTables } from "../../ingredient/durable-object/ingredient-tables";
import { mealTables } from "../../meal/durable-object/meal-tables";
import type { DishStore } from "../domain/dish-store";
import { dishTables } from "./dish-tables";
import { findNewestDishEstimatedQuantity } from "./find-newest-dish-estimation";

const {
  dishes,
  dishEstimationApplications,
  dishEstimatedQuantities,
  dishNameCorrections,
  dishQuantityCorrections,
  dishEstimationSchedules,
  dishDeletions,
} = dishTables;
const { syncWriteReceipts } = syncLedgerTables;
const { ingredients, ingredientQuantityCorrections } = ingredientTables;
const { mealEatenAtCorrections } = mealTables;
const { estimations } = estimationTables;

// 料理の ID は食事の数ほど届きうるので、変数の上限（100）を超えないよう1行ずつ消し・書く
export const createDishStore = (db: DrizzleSqliteDODatabase): DishStore => ({
  find: (id) => {
    const dish = db.select().from(dishes).where(eq(dishes.id, id)).get();
    if (dish === undefined) {
      return undefined;
    }
    const estimatedQuantity = findNewestDishEstimatedQuantity(db, id);
    if (estimatedQuantity === undefined) {
      // 今は料理を推定の完了でだけ作り、同じトランザクションで量つきの当てた推定を書くので起きない
      throw new Error(`料理 ${id} に量を持つ当てた推定が無い`);
    }
    return { ...dish, ...estimatedQuantity, version: countVersion(db, dish) };
  },
  hasDeletion: (id) =>
    db
      .select({ id: dishDeletions.dishId })
      .from(dishDeletions)
      .where(eq(dishDeletions.dishId, id))
      .get() !== undefined,
  findIdsOfMeal: (mealId) =>
    db
      .select({ id: dishes.id })
      .from(dishes)
      .where(eq(dishes.mealId, mealId))
      .all()
      .map(({ id }) => id),
  insert: (dish) => {
    db.insert(dishes).values(dish).run();
  },
  insertEstimationApplication: ({ dishId, estimationId, estimatedQuantity }) => {
    db.insert(dishEstimationApplications).values({ dishId, estimationId }).run();
    db.insert(dishEstimatedQuantities)
      .values({ dishId, estimationId, ...estimatedQuantity })
      .run();
  },
  remove: (ids) => {
    for (const id of ids) {
      db.delete(dishes).where(eq(dishes.id, id)).run();
    }
  },
  insertDeletions: (ids, receiptId) => {
    for (const dishId of ids) {
      db.insert(dishDeletions).values({ dishId, syncWriteReceiptId: receiptId.value }).run();
    }
  },
});

// 版は、1 ＋ 名前の修正 ＋ 料理の量の修正 ＋ その料理の材料（前の推定の材料も）の量の修正 ＋ その食事の時刻の修正 ＋ 料理が対象の推定を当てた数。
// 出来事は料理を消すまで消えないので、版は下がらない。数える出来事の種類は足すだけにする（減らすと版が下がり、ヘルスケアが書き直されない）。
// 修正は控えの索引 sync_write_receipts_record (record_type, record_id) で引く。材料の分を材料と控えの結合で書くと、
// 統計の無い DB では控えの record_type だけで引き、材料への書き込みの控えを全部読むので、材料の ID の副問い合わせで書く
const countVersion = (db: DrizzleSqliteDODatabase, dish: { id: string; mealId: string }): number =>
  1 +
  countCorrections(
    db,
    dishNameCorrections,
    and(eq(syncWriteReceipts.recordType, "dish"), eq(syncWriteReceipts.recordId, dish.id)),
  ) +
  countCorrections(
    db,
    dishQuantityCorrections,
    and(eq(syncWriteReceipts.recordType, "dish"), eq(syncWriteReceipts.recordId, dish.id)),
  ) +
  countCorrections(
    db,
    ingredientQuantityCorrections,
    and(
      eq(syncWriteReceipts.recordType, "ingredient"),
      inArray(
        syncWriteReceipts.recordId,
        db.select({ id: ingredients.id }).from(ingredients).where(eq(ingredients.dishId, dish.id)),
      ),
    ),
  ) +
  countCorrections(
    db,
    mealEatenAtCorrections,
    and(eq(syncWriteReceipts.recordType, "meal"), eq(syncWriteReceipts.recordId, dish.mealId)),
  ) +
  (db
    .select({ total: count() })
    .from(dishEstimationApplications)
    .innerJoin(estimations, eq(estimations.id, dishEstimationApplications.estimationId))
    .innerJoin(
      dishEstimationSchedules,
      eq(dishEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
    )
    .where(eq(dishEstimationApplications.dishId, dish.id))
    .get()?.total ?? 0);

// 控えだけを指す修正の表の行のうち、条件に合う控えのものを数える
const countCorrections = (
  db: DrizzleSqliteDODatabase,
  corrections:
    | typeof dishNameCorrections
    | typeof dishQuantityCorrections
    | typeof ingredientQuantityCorrections
    | typeof mealEatenAtCorrections,
  receiptCondition: ReturnType<typeof and>,
): number =>
  db
    .select({ total: count() })
    .from(corrections)
    .innerJoin(syncWriteReceipts, eq(syncWriteReceipts.id, corrections.syncWriteReceiptId))
    .where(receiptCondition)
    .get()?.total ?? 0;
