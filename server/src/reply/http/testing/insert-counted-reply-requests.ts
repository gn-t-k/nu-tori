import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { generateRecordId } from "../../../domain/record-id";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 数える日 countedOn の返事の依頼を書く。generated 個は生成して作れなかったまで（回数に数える）、halted 個は回数切れにする。
// どれもきっかけを持たないので、アラームは待っている依頼にも続いている生成にも拾わず、回数にだけ効く
export const insertCountedReplyRequests = (
  accountId: string,
  countedOn: string,
  counts: { generated: number; halted: number },
) =>
  runInDurableObject(getAccountDurableObject(env, accountId), (_, state) => {
    const insertRequest = (): string => {
      const sentTextId = generateRecordId();
      state.storage.sql.exec(
        "INSERT INTO sent_texts (id, body, sent_at, sent_time_zone) VALUES (?, ?, ?, ?)",
        sentTextId,
        "回数を満たすための文章",
        0,
        "Asia/Tokyo",
      );
      const requestId = generateRecordId();
      state.storage.sql.exec(
        "INSERT INTO reply_requests (id, sent_text_id, counted_on) VALUES (?, ?, ?)",
        requestId,
        sentTextId,
        countedOn,
      );
      return requestId;
    };
    for (let index = 0; index < counts.generated; index += 1) {
      const generationId = generateRecordId();
      state.storage.sql.exec(
        "INSERT INTO reply_generations (id, reply_request_id, started_at) VALUES (?, ?, ?)",
        generationId,
        insertRequest(),
        0,
      );
      state.storage.sql.exec(
        "INSERT INTO reply_generation_abandonments (reply_generation_id, abandoned_at) VALUES (?, ?)",
        generationId,
        0,
      );
    }
    for (let index = 0; index < counts.halted; index += 1) {
      state.storage.sql.exec(
        "INSERT INTO reply_request_halts (reply_request_id, halted_at) VALUES (?, ?)",
        insertRequest(),
        0,
      );
    }
  });
