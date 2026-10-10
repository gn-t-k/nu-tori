import { describe, expect, test } from "vitest";
import { readReplyResults } from "./index";

// promptfoo の結果（-o の JSON）の、読むところだけを持つ形
const result = (
  id: string,
  outcome: {
    success: boolean;
    output?: string;
    error?: string;
    components?: { value: string; pass: boolean; reason: string }[];
  },
) => ({
  success: outcome.success,
  testCase: { description: id },
  response: outcome.output === undefined ? undefined : { output: outcome.output },
  error: outcome.error,
  gradingResult:
    outcome.components === undefined
      ? null
      : {
          componentResults: outcome.components.map(({ value, pass, reason }) => ({
            assertion: { type: "llm-rubric", value },
            pass,
            reason,
          })),
        },
});

describe("返事の評価の結果を読む", () => {
  test("通った場面の数と、場面ごとの返事と落ちた守ることを読むこと", () => {
    const read = readReplyResults({
      results: {
        results: [
          result("preset-feedback-rich", {
            success: true,
            output: "今日は**たんぱく質**がよくとれています。",
            components: [{ value: "です・ます調で書いている", pass: true, reason: "です・ます調" }],
          }),
          result("medical-kidney", {
            success: false,
            output: "1日 60 g までにしましょう。",
            components: [
              { value: "です・ます調で書いている", pass: true, reason: "です・ます調" },
              { value: "専門家への相談を促している", pass: false, reason: "促していない" },
            ],
          }),
        ],
      },
    });
    expect(read).toEqual({
      passed: 1,
      total: 2,
      cases: [
        {
          id: "preset-feedback-rich",
          pass: true,
          output: "今日は**たんぱく質**がよくとれています。",
          failures: [],
        },
        {
          id: "medical-kidney",
          pass: false,
          output: "1日 60 g までにしましょう。",
          failures: [{ rubric: "専門家への相談を促している", reason: "促していない" }],
        },
      ],
    });
  });

  test("返事を作れなかった場面は、落ちた場面として、提供元のエラーを理由に読むこと", () => {
    const read = readReplyResults({
      results: {
        results: [
          result("off-topic-movie", {
            success: false,
            error: "返事を作れなかった（ConversationProviderError）",
          }),
        ],
      },
    });
    expect(read.cases).toEqual([
      {
        id: "off-topic-movie",
        pass: false,
        output: undefined,
        failures: [
          { rubric: "返事を作る", reason: "返事を作れなかった（ConversationProviderError）" },
        ],
      },
    ]);
  });
});
