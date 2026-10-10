import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match } from "ts-pattern";
import type { ReplyRequestStore } from "../domain/reply-request-store";
import { replyTables } from "./reply-tables";

const { replyRequests, classificationReplyRequests, conversationResendReplyRequests } = replyTables;

export const createReplyRequestStore = (db: DrizzleSqliteDODatabase): ReplyRequestStore => ({
  insert: ({ id, sentTextId, countedOn, trigger }) => {
    db.insert(replyRequests).values({ id, sentTextId, countedOn }).run();
    match(trigger)
      .with({ type: "classification" }, () => {
        db.insert(classificationReplyRequests).values({ replyRequestId: id }).run();
      })
      .with({ type: "conversation_resend" }, ({ receiptId }) => {
        db.insert(conversationResendReplyRequests)
          .values({ replyRequestId: id, syncWriteReceiptId: receiptId.value })
          .run();
      })
      .exhaustive();
  },
});
