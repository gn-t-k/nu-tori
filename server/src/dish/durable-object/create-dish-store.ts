import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { DishStore } from "../domain/dish-store";
import { dishTables } from "./dish-tables";

const { dishes, dishDeletions, syncWriteDishDeletions } = dishTables;

// 料理の ID は食事の数ほど届きうるので、変数の上限（100）を超えないよう1行ずつ消し・書く
export const createDishStore = (db: DrizzleSqliteDODatabase): DishStore => ({
  find: (id) => db.select().from(dishes).where(eq(dishes.id, id)).get(),
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
  remove: (ids) => {
    for (const id of ids) {
      db.delete(dishes).where(eq(dishes.id, id)).run();
    }
  },
  insertDeletions: (ids, receiptId) => {
    for (const dishId of ids) {
      db.insert(dishDeletions).values({ dishId }).run();
      db.insert(syncWriteDishDeletions)
        .values({ dishId, syncWriteReceiptId: receiptId.value })
        .run();
    }
  },
});
