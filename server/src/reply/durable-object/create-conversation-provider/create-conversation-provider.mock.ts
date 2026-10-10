import { R } from "@praha/byethrow";
import { vi } from "vitest";
import type { TokenUsage } from "../../../estimation/domain/estimation-provider";
import type { ClassificationLabel, ConversationProvider } from "../../domain/conversation-provider";
import type { ConversationProviderError } from "../../domain/conversation-provider-error";
import * as module from "./index";

type FakeReplies = {
  classification: ClassificationLabel;
  classificationUsage: TokenUsage;
};

// 答える偽の提供元。読み分けの既定は食事。偽物の classifySentText は呼び出しを記録する
export const mockCreateConversationProviderOk = (overrides?: Partial<FakeReplies>) => {
  const replies: FakeReplies = { ...defaultReplies, ...overrides };
  const provider: ConversationProvider = {
    classifySentText: vi.fn<ConversationProvider["classifySentText"]>(async () =>
      R.succeed({ label: replies.classification, usage: replies.classificationUsage }),
    ),
  };
  return vi.spyOn(module, "createConversationProvider").mockReturnValue(provider);
};

// 呼び出しが失敗する偽の提供元
export const mockCreateConversationProviderError = (error: ConversationProviderError) => {
  const provider: ConversationProvider = {
    classifySentText: async () => R.fail(error),
  };
  return vi.spyOn(module, "createConversationProvider").mockReturnValue(provider);
};

const defaultReplies: FakeReplies = {
  classification: "meal",
  classificationUsage: { inputTokens: 120, outputTokens: 4 },
};
