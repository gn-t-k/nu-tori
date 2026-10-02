import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { NoticeStore } from "../domain/notice-store";
import { noticeTables } from "./notice-tables";

const { notices, missedRecordNotices, noticeResponses } = noticeTables;

export const createNoticeStore = (db: DrizzleSqliteDODatabase): NoticeStore => ({
  find: (id) => {
    const row = db
      .select({ notice: notices, missedRecord: missedRecordNotices, response: noticeResponses })
      .from(notices)
      .innerJoin(missedRecordNotices, eq(missedRecordNotices.noticeId, notices.id))
      .leftJoin(noticeResponses, eq(noticeResponses.noticeId, notices.id))
      .where(eq(notices.id, id))
      .get();
    return row === undefined
      ? undefined
      : {
          id: row.notice.id,
          noticeType: row.notice.noticeType,
          issuedAt: row.notice.issuedAt,
          timeZone: row.notice.timeZone,
          targetOn: row.missedRecord.targetOn,
          response:
            row.response === null
              ? undefined
              : { respondedAt: row.response.respondedAt, timeZone: row.response.timeZone },
        };
  },
  insert: ({ id, noticeType, issuedAt, timeZone, targetOn }) => {
    db.insert(notices).values({ id, noticeType, issuedAt, timeZone }).run();
    db.insert(missedRecordNotices).values({ noticeId: id, targetOn }).run();
  },
  insertResponse: (receiptId, noticeId, { respondedAt, timeZone }) => {
    db.insert(noticeResponses)
      .values({ syncWriteReceiptId: receiptId.value, noticeId, respondedAt, timeZone })
      .run();
  },
});
