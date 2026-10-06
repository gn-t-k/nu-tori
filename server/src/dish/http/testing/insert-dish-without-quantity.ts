import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 量の無い料理（足したばかりで、推定し直しが一度も当たっていない料理）を、食事に直に置く。
// 料理を足す書き込みがまだ無いため。料理を足すチケットで、その書き込みに置き換えてこのヘルパーを消す
export const insertDishWithoutQuantity = (
  accountId: string,
  mealId: string,
  name: string,
): Promise<string> =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const dishId = crypto.randomUUID();
    state.storage.sql.exec(
      "INSERT INTO dishes (id, meal_id, name, position_in_meal) VALUES (?, ?, ?, 0)",
      dishId,
      mealId,
      name,
    );
    return dishId;
  });
