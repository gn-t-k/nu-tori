import { env } from "cloudflare:workers";
import { app } from "../../app";

// 送った文章の見守る要求をつなぐ。応答は流れのまま返る
export const watchReplyStream = (sessionToken: string, sentTextId: string) =>
  app.request(
    `/v1/sent-texts/${sentTextId}/reply-stream`,
    { headers: { authorization: `Bearer ${sessionToken}` } },
    env,
  );
