import { and, count, desc, eq, inArray, sql } from "drizzle-orm";
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
  dishQuantityCorrectionIngredients,
  dishEstimationSchedules,
  dishDeletions,
} = dishTables;
const { syncWriteReceipts, syncWriteRecordChanges } = syncLedgerTables;
const { ingredients, ingredientQuantityCorrections } = ingredientTables;
const { mealEatenAtCorrections } = mealTables;
const { estimations, estimationCompletions, estimationAbandonments } = estimationTables;

// 料理の ID は食事の数ほど届きうるので、変数の上限（100）を超えないよう1行ずつ消し・書く
export const createDishStore = (db: DrizzleSqliteDODatabase): DishStore => ({
  find: (id) => {
    const dish = db.select().from(dishes).where(eq(dishes.id, id)).get();
    if (dish === undefined) {
      return undefined;
    }
    const estimatedQuantity = findNewestDishEstimatedQuantity(db, id);
    const correctedQuantity = findLatestQuantity(db, id);
    return {
      ...dish,
      name: findLatestName(db, id) ?? dish.name,
      // 量を直す書き込みは、量を持つ当てた推定の無い料理では受け付けないので、直した量だけがあることは無い
      quantity:
        estimatedQuantity === undefined
          ? undefined
          : {
              value: correctedQuantity ?? estimatedQuantity.quantity,
              unit: estimatedQuantity.unit,
              source: correctedQuantity === undefined ? "estimated" : "corrected",
            },
      version: countVersion(db, dish),
    };
  },
  exists: (id) =>
    db.select({ id: dishes.id }).from(dishes).where(eq(dishes.id, id)).get() !== undefined,
  findNewestReestimationEndedAt: (id) =>
    db
      .select({
        endedAt: sql<number>`coalesce(${estimationCompletions.completedAt}, ${estimationAbandonments.abandonedAt})`,
      })
      .from(dishEstimationApplications)
      .innerJoin(estimations, eq(estimations.id, dishEstimationApplications.estimationId))
      .innerJoin(
        dishEstimationSchedules,
        eq(dishEstimationSchedules.estimationScheduleId, estimations.estimationScheduleId),
      )
      .leftJoin(estimationCompletions, eq(estimationCompletions.estimationId, estimations.id))
      .leftJoin(estimationAbandonments, eq(estimationAbandonments.estimationId, estimations.id))
      .where(eq(dishEstimationApplications.dishId, id))
      .orderBy(
        desc(
          sql`coalesce(${estimationCompletions.completedAt}, ${estimationAbandonments.abandonedAt})`,
        ),
      )
      .limit(1)
      .all()
      .map(({ endedAt }) => new Date(endedAt))[0],
  hasDeletion: (id) =>
    db
      .select({ id: dishDeletions.dishId })
      .from(dishDeletions)
      .where(eq(dishDeletions.dishId, id))
      .get() !== undefined,
  wasAddedByUser: (id) =>
    db
      .select({ id: syncWriteReceipts.id })
      .from(syncWriteReceipts)
      .where(
        and(
          eq(syncWriteReceipts.recordType, "dish"),
          eq(syncWriteReceipts.recordId, id),
          eq(syncWriteReceipts.kind, "create"),
          eq(syncWriteReceipts.result, "applied"),
        ),
      )
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
    if (estimatedQuantity !== undefined) {
      db.insert(dishEstimatedQuantities)
        .values({ dishId, estimationId, ...estimatedQuantity })
        .run();
    }
  },
  insertNameCorrection: (receiptId, name) => {
    db.insert(dishNameCorrections).values({ syncWriteReceiptId: receiptId.value, name }).run();
  },
  insertQuantityCorrection: (receiptId, { value, proportionedIngredients }) => {
    db.insert(dishQuantityCorrections)
      .values({ syncWriteReceiptId: receiptId.value, quantity: value })
      .run();
    for (const { ingredientId, quantity } of proportionedIngredients) {
      db.insert(dishQuantityCorrectionIngredients)
        .values({ syncWriteReceiptId: receiptId.value, ingredientId, quantity })
        .run();
    }
  },
  remove: (ids) => {
    for (const id of ids) {
      db.delete(dishes).where(eq(dishes.id, id)).run();
    }
  },
  removeCorrections: (ids) => {
    for (const id of ids) {
      const receiptIds = db
        .select({ id: syncWriteReceipts.id })
        .from(syncWriteReceipts)
        .where(and(eq(syncWriteReceipts.recordType, "dish"), eq(syncWriteReceipts.recordId, id)));
      db.delete(dishNameCorrections)
        .where(inArray(dishNameCorrections.syncWriteReceiptId, receiptIds))
        .run();
      db.delete(dishQuantityCorrections)
        .where(inArray(dishQuantityCorrections.syncWriteReceiptId, receiptIds))
        .run();
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

// 料理を書き換えた控えの修正のうち、受け取った順（控えを当てたときの変更の通し番号）でいちばんあとのもの
const findLatestName = (db: DrizzleSqliteDODatabase, dishId: string): string | undefined =>
  db
    .select({ name: dishNameCorrections.name })
    .from(dishNameCorrections)
    .innerJoin(syncWriteReceipts, eq(syncWriteReceipts.id, dishNameCorrections.syncWriteReceiptId))
    .innerJoin(
      syncWriteRecordChanges,
      eq(syncWriteRecordChanges.syncWriteReceiptId, dishNameCorrections.syncWriteReceiptId),
    )
    .where(receiptOfDish(dishId))
    .orderBy(desc(syncWriteRecordChanges.recordChangeSequence))
    .limit(1)
    .get()?.name;

const findLatestQuantity = (db: DrizzleSqliteDODatabase, dishId: string): number | undefined =>
  db
    .select({ quantity: dishQuantityCorrections.quantity })
    .from(dishQuantityCorrections)
    .innerJoin(
      syncWriteReceipts,
      eq(syncWriteReceipts.id, dishQuantityCorrections.syncWriteReceiptId),
    )
    .innerJoin(
      syncWriteRecordChanges,
      eq(syncWriteRecordChanges.syncWriteReceiptId, dishQuantityCorrections.syncWriteReceiptId),
    )
    .where(receiptOfDish(dishId))
    .orderBy(desc(syncWriteRecordChanges.recordChangeSequence))
    .limit(1)
    .get()?.quantity;

const receiptOfDish = (dishId: string) =>
  and(eq(syncWriteReceipts.recordType, "dish"), eq(syncWriteReceipts.recordId, dishId));

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
