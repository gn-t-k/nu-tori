import { R } from "@praha/byethrow";
import { vi } from "vitest";
import type { RecordId } from "../../../domain/record-id";
import type { TokenUsage } from "../../../estimation/domain/estimation-provider";
import type { ClassificationLabel, ConversationProvider } from "../../domain/conversation-provider";
import type { ConversationProviderError } from "../../domain/conversation-provider-error";
import type { ReplyContext } from "../../domain/reply-context";
import * as module from "./index";

type FakeReply = { body: string; mealIds: readonly RecordId[] };

type FakeReplies = {
  classification: ClassificationLabel;
  classificationUsage: TokenUsage;
  // 文脈から返事を作るときは関数で渡す（文脈で ID を付けた食事を指し示させるのに使う）
  reply: FakeReply | ((context: ReplyContext) => FakeReply);
  replyUsage: TokenUsage;
};

// 答える偽の提供元。読み分けの既定は食事、返事の既定は食事を指し示さない返事。
// 偽物の classifySentText と generateReply は呼び出しを記録する
export const mockCreateConversationProviderOk = (overrides?: Partial<FakeReplies>) => {
  const replies: FakeReplies = { ...defaultReplies, ...overrides };
  const provider: ConversationProvider = {
    classifySentText: vi.fn<ConversationProvider["classifySentText"]>(async () =>
      R.succeed({ label: replies.classification, usage: replies.classificationUsage }),
    ),
    generateReply: vi.fn<ConversationProvider["generateReply"]>(async ({ context }) =>
      R.succeed({
        ...(typeof replies.reply === "function" ? replies.reply(context) : replies.reply),
        usage: replies.replyUsage,
      }),
    ),
  };
  return vi.spyOn(module, "createConversationProvider").mockReturnValue(provider);
};

// 呼び出しが失敗する偽の提供元。読み分けが落ちるとき（会話になる）は、返事は既定の返事で答える。
// 返事が落ちるときは、読み分けは会話と答える
export const mockCreateConversationProviderError = (
  failure:
    | { failingCall: "classify_sent_text"; error: ConversationProviderError }
    | {
        failingCall: "generate_reply";
        error: R.InferFailure<ConversationProvider["generateReply"]>;
      },
) => {
  const provider: ConversationProvider = {
    classifySentText: async () =>
      failure.failingCall === "classify_sent_text"
        ? R.fail(failure.error)
        : R.succeed({ label: "conversation", usage: defaultReplies.classificationUsage }),
    generateReply: async () =>
      failure.failingCall === "generate_reply"
        ? R.fail(failure.error)
        : R.succeed({ ...defaultReply, usage: defaultReplies.replyUsage }),
  };
  return vi.spyOn(module, "createConversationProvider").mockReturnValue(provider);
};

const defaultReply: FakeReply = {
  body: "お疲れさまです。今日の記録を見ながら、一緒に考えますね。",
  mealIds: [],
};

const defaultReplies: FakeReplies = {
  classification: "meal",
  classificationUsage: { inputTokens: 120, outputTokens: 4 },
  reply: defaultReply,
  replyUsage: { inputTokens: 2400, outputTokens: 180 },
};
