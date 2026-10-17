import { beforeEach, describe, expect, test } from "vitest";
import { summarizeReplyResults } from "./index";

// promptfoo の結果（-o の JSON）の1行の、読むところだけを持つ形
const result = (testIdx: number, id: string, success: boolean) => ({
  success,
  testIdx,
  testCase: { description: id },
  response: { output: `${id} の返事` },
  gradingResult: {
    componentResults: [
      {
        assertion: { type: "llm-rubric", value: "です・ます調で書いている" },
        pass: success,
        reason: "理由",
      },
    ],
  },
});

describe("返事の評価の結果を要約する", () => {
  describe("どれかの回で落ちた場面があるとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          results: [
            result(0, "off-topic-movie", true),
            result(1, "off-topic-movie", true),
            result(2, "medical-kidney", true),
            result(3, "medical-kidney", false),
          ],
        },
      };
    });

    test("その場面を、すべての回で通った場面に数えないこと", () => {
      expect(summarizeReplyResults(results).summary).toContain("すべての回で通った場面: 1 / 2");
    });

    test("その場面を、落ちた場面に並べること", () => {
      const { summary } = summarizeReplyResults(results);

      expect({
        medicalKidney: summary.includes("## 落ちた場面: medical-kidney"),
        offTopicMovie: summary.includes("## 落ちた場面: off-topic-movie"),
      }).toEqual({ medicalKidney: true, offTopicMovie: false });
    });

    test("通らなかったとすること", () => {
      expect(summarizeReplyResults(results).passed).toBe(false);
    });
  });

  describe("すべての場面がすべての回で通ったとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          results: [result(0, "off-topic-movie", true), result(1, "medical-kidney", true)],
        },
      };
    });

    test("通ったとすること", () => {
      expect(summarizeReplyResults(results).passed).toBe(true);
    });
  });
});
