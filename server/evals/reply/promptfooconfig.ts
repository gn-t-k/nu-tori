import type { UnifiedConfig } from "promptfoo";
import { listReferableMealIds } from "../../src/reply/domain/list-referable-meal-ids";
import { renderReplyContext } from "../../src/reply/domain/render-reply-context";
import { replyEvalCases } from "./cases";
import { commonRubric, replyMaxLength } from "./common-rubric";
import { gradingPrompt } from "./grading-prompt";
import type { ReplyShapeConfig } from "./judge-reply-shape";

// 返事の指示の評価（#419 の「指示と評価」、#434）。30 場面の返事を Claude Sonnet 5.5 に作らせ、
// 守ることを1項目ずつ判定役の Claude Opus 5.5 が判定し、長さと指し示す食事をコードで確かめる。30 場面すべてが通れば合格。
// 回し方と鍵は summarize-reply-results.ts
const config: Partial<UnifiedConfig> = {
  description: "返事の指示の評価（Claude Sonnet 5.5）",
  prompts: ["{{caseId}}"],
  providers: [{ id: "file://sonnet-reply-provider.ts", label: "sonnet" }],
  defaultTest: {
    options: { provider: "file://judge-provider.ts", rubricPrompt: gradingPrompt },
  },
  tests: replyEvalCases.map(({ id, context, rubric, expectedMealIds }) => {
    const shape: ReplyShapeConfig = {
      maxLength: replyMaxLength,
      referableMealIds: [...listReferableMealIds(context)],
      expectedMealIds,
    };
    return {
      description: id,
      vars: {
        caseId: id,
        // 判定役に見せる文脈。返事を作るときに渡した文の塊と同じもの
        contextText: renderReplyContext(context)
          .map(({ text }) => text)
          .join("\n\n"),
      },
      assert: [
        ...[...commonRubric, ...rubric].map((value) => ({ type: "llm-rubric" as const, value })),
        {
          type: "javascript" as const,
          value: "file://judge-reply-shape/judge-reply-shape.ts:judgeReplyShape",
          config: shape,
        },
      ],
    };
  }),
};

export default config;
