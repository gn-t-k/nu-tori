import { runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { getAccountDurableObject } from "../../../durable-object/get-account-durable-object";

// 記録忘れの知らせの子の行の数。対象の日付を持たない知らせが子の行を書かないことは、同期の応答に出ないので、表を読む
export const countMissedRecordNotices = (accountId: string, noticeId: string): Promise<number> =>
  runInDurableObject(
    getAccountDurableObject(env, accountId),
    (_, state) =>
      state.storage.sql
        .exec<{ total: number }>(
          "SELECT count(*) AS total FROM missed_record_notices WHERE notice_id = ?",
          noticeId,
        )
        .one().total,
  );
