import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match } from "ts-pattern";
import type { NoticeSubject, NoticeType } from "../domain/notice";
import type { NoticeStore } from "../domain/notice-store";
import { noticeTables } from "./notice-tables";

const { notices, missedRecordNotices, noticeResponses } = noticeTables;

export const createNoticeStore = (db: DrizzleSqliteDODatabase): NoticeStore => ({
  find: (id) => {
    // 記録忘れの知らせの子の行は、対象の日付を持つ種類にだけあるので、外部結合で読む
    const row = db
      .select({ notice: notices, missedRecord: missedRecordNotices, response: noticeResponses })
      .from(notices)
      .leftJoin(missedRecordNotices, eq(missedRecordNotices.noticeId, notices.id))
      .leftJoin(noticeResponses, eq(noticeResponses.noticeId, notices.id))
      .where(eq(notices.id, id))
      .get();
    return row === undefined
      ? undefined
      : {
          id: row.notice.id,
          issuedAt: row.notice.issuedAt,
          timeZone: row.notice.timeZone,
          ...toSubject(row.notice.noticeType, row.missedRecord),
          response:
            row.response === null
              ? undefined
              : { respondedAt: row.response.respondedAt, timeZone: row.response.timeZone },
        };
  },
  insert: (notice) => {
    const { id, issuedAt, timeZone } = notice;
    db.insert(notices).values({ id, noticeType: notice.noticeType, issuedAt, timeZone }).run();
    match(notice)
      .with({ noticeType: "missed_weight_record" }, ({ targetOn }) => {
        db.insert(missedRecordNotices).values({ noticeId: id, targetOn }).run();
      })
      .with({ noticeType: "goal_setup" }, () => {})
      .exhaustive();
  },
  insertResponse: (receiptId, noticeId, { respondedAt, timeZone }) => {
    db.insert(noticeResponses)
      .values({ syncWriteReceiptId: receiptId.value, noticeId, respondedAt, timeZone })
      .run();
  },
});

const toSubject = (
  noticeType: NoticeType,
  missedRecord: typeof missedRecordNotices.$inferSelect | null,
): NoticeSubject =>
  match(noticeType)
    .with("missed_weight_record", (missedWeightRecord) => {
      if (missedRecord === null) {
        throw new Error("記録忘れの知らせに、対象の日付の行が無い");
      }
      return { noticeType: missedWeightRecord, targetOn: missedRecord.targetOn };
    })
    .with("goal_setup", (goalSetup) => ({ noticeType: goalSetup }))
    .exhaustive();
