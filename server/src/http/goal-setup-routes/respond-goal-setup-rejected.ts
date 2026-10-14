import { captureException } from "@sentry/cloudflare";
import type { Context } from "hono";
import type { GoalSetupRequestRejectedError } from "../../goal/domain/goal-setup-request-rejected-error";

// 値を受け付けなかった要求は不具合のときだけ届くので、Sentry に送ってから 422 で理由を返す
export const respondGoalSetupRejected = (c: Context, error: GoalSetupRequestRejectedError) => {
  captureException(error);
  return c.json({ code: error.reason }, 422);
};
