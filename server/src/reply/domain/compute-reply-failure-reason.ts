import type { ReplyFailureReason } from "../../sent-text-status/domain/sent-text-status";
import type { ReplyAttemptConclusion } from "./reply-attempt";

// 作れなかった理由。最後の試みの結果が 400 なら bad_request、ほか（結果の無い試みを含む）はやり直しを使い切った
export const computeReplyFailureReason = (
  lastAttemptResult: ReplyAttemptConclusion["result"] | undefined,
): ReplyFailureReason =>
  lastAttemptResult === "bad_request" ? "bad_request" : "retries_exhausted";
