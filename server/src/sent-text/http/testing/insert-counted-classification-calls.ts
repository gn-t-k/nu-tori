import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 提供元を呼んで会話と読み分けた文章を、呼んだ時刻 calledAt の分として count 個ぶん書く。
// 返事の依頼を持たないので、アラームは読み分けにも返事にも拾わず、読み分けの回数にだけ数える
export const insertCountedClassificationCalls = (
  accountId: string,
  calledAt: number,
  count: number,
) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    for (let index = 0; index < count; index += 1) {
      const sentTextId = generateRecordId();
      state.storage.sql.exec(
        "INSERT INTO sent_texts (id, body, sent_at, sent_time_zone) VALUES (?, ?, ?, ?)",
        sentTextId,
        "回数を満たすための文章",
        0,
        "Asia/Tokyo",
      );
      state.storage.sql.exec(
        "INSERT INTO sent_text_classifications (sent_text_id, classified_at, result) VALUES (?, ?, ?)",
        sentTextId,
        0,
        "conversation",
      );
      state.storage.sql.exec(
        "INSERT INTO sent_text_classification_calls (id, sent_text_id, called_at) VALUES (?, ?, ?)",
        generateRecordId(),
        sentTextId,
        calledAt,
      );
    }
  });
