import type { RecordKindStores } from "../../../domain/record-kind-stores";
import type { SentText } from "../../../sent-text/domain/sent-text";
import type { ReplyContext } from "../reply-context";
import { assembleReplyContext } from "./assemble-reply-context";
import { readReplyContextSource } from "./read-reply-context-source";

// 応える送った文章の、返事を作るときに AI に渡す文脈を、置き場の記録から組み立てる。
// 読む範囲は、文脈に入れる範囲（replyContextSpan）から出すので、ずれない。
// now は、料理が推定し直しを待っているかを決める時刻と、読む体重記録の終わり
export const buildReplyContext = (
  stores: Pick<
    RecordKindStores,
    | "sentText"
    | "reply"
    | "aiUtterance"
    | "meal"
    | "mealEstimationStatus"
    | "dish"
    | "dishEstimationStatus"
    | "ingredient"
    | "weightRecord"
    | "goal"
    | "dailyGuide"
    | "expenditureEstimate"
    | "weeklyReview"
  >,
  sentText: SentText,
  now: Date,
): ReplyContext => assembleReplyContext(readReplyContextSource(stores, sentText, now));
