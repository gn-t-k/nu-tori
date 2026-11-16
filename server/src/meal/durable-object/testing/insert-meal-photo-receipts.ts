import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// どの食事も宣言していない写真の受け取りを、数だけ控える。R2 には置かない
export const insertMealPhotoReceipts = (accountId: string, count: number, receivedAt: number) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    for (let index = 0; index < count; index += 1) {
      state.storage.sql.exec(
        "INSERT INTO meal_photo_file_receipts (meal_photo_id, received_at) VALUES (?, ?)",
        generateRecordId(),
        receivedAt,
      );
    }
  });
