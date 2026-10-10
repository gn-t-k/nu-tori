import { R } from "@praha/byethrow";
import type { ConversationProvider } from "../../domain/conversation-provider";
import { ConversationProviderError } from "../../domain/conversation-provider-error";

// 提供元の差し替えの口。Durable Object が読み分けと返事のたびにここから提供元を得る。テストは同じフォルダの mock で偽物に差し替える。
// 本物の読み分けは #432 でつなぐ。つなぐまでは呼び出しの失敗を返し、どの文章も会話にする（#419 の「決めかねたとき」）
export const createConversationProvider = (
  _env: Env,
  _accountId: string,
): ConversationProvider => ({
  classifySentText: async () =>
    R.fail(new ConversationProviderError({ errorType: "not_connected" })),
});
