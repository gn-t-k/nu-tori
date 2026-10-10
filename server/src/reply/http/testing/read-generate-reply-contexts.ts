import { env } from "cloudflare:workers";
import { vi } from "vitest";
import type { ReplyContext } from "../../domain/reply-context";
import type { mockCreateConversationProviderOk } from "../../durable-object/create-conversation-provider/create-conversation-provider.mock";

// いま差してある偽の提供元が、返事を作る呼び出しで受け取った文脈を、受け取った順に読む。
// 偽の提供元を差し直すと spy は同じまま返す提供元が変わるので、spy の今の実装から提供元を得る
export const readGenerateReplyContexts = (
  spy: ReturnType<typeof mockCreateConversationProviderOk>,
): ReplyContext[] => {
  const provider = spy.getMockImplementation()?.(env, "account-of-reader");
  return provider === undefined
    ? []
    : vi.mocked(provider.generateReply).mock.calls.map(([request]) => request.context);
};
