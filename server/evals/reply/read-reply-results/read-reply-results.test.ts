import { beforeEach, describe, expect, test } from "vitest";
import { readReplyResults } from "./index";

// promptfoo の結果（-o の JSON）の、読むところだけを持つ形
const result = (
  testIdx: number,
  id: string,
  outcome: {
    success: boolean;
    output?: string;
    error?: string;
    components?: { value: string; pass: boolean; reason: string }[];
  },
) => ({
  success: outcome.success,
  testIdx,
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
  describe("場面ごとに1回回したとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          results: [
            result(0, "preset-feedback-rich", {
              success: true,
              output: "今日は**たんぱく質**がよくとれています。",
              components: [
                { value: "です・ます調で書いている", pass: true, reason: "です・ます調" },
              ],
            }),
            result(1, "medical-kidney", {
              success: false,
              output: "1日 60 g までにしましょう。",
              components: [
                { value: "です・ます調で書いている", pass: true, reason: "です・ます調" },
                { value: "専門家への相談を促している", pass: false, reason: "促していない" },
              ],
            }),
          ],
        },
      };
    });

    test("場面ごとの返事と落ちた守ることを読むこと", () => {
      expect(readReplyResults(results)).toEqual([
        {
          id: "preset-feedback-rich",
          runs: [{ pass: true, output: "今日は**たんぱく質**がよくとれています。", failures: [] }],
        },
        {
          id: "medical-kidney",
          runs: [
            {
              pass: false,
              output: "1日 60 g までにしましょう。",
              failures: [{ rubric: "専門家への相談を促している", reason: "促していない" }],
            },
          ],
        },
      ]);
    });
  });

  describe("同じ場面を何回か回し、promptfoo が回し終えた順に並べたとき", () => {
    let results: unknown;
    beforeEach(() => {
      // --repeat 2 の testIdx は、1つ目の場面が 0 と 1、2つ目が 2 と 3
      results = {
        results: {
          results: [
            result(2, "medical-kidney", { success: true, output: "1回目", components: [] }),
            result(1, "off-topic-movie", { success: true, output: "2回目", components: [] }),
            result(3, "medical-kidney", {
              success: false,
              output: "2回目",
              components: [
                { value: "専門家への相談を促している", pass: false, reason: "促していない" },
              ],
            }),
            result(0, "off-topic-movie", { success: true, output: "1回目", components: [] }),
          ],
        },
      };
    });

    test("評価の組の順に、場面ごとに回を並べてまとめること", () => {
      expect(
        readReplyResults(results).map(({ id, runs }) => ({
          id,
          runs: runs.map(({ pass, output }) => ({ pass, output })),
        })),
      ).toEqual([
        {
          id: "off-topic-movie",
          runs: [
            { pass: true, output: "1回目" },
            { pass: true, output: "2回目" },
          ],
        },
        {
          id: "medical-kidney",
          runs: [
            { pass: true, output: "1回目" },
            { pass: false, output: "2回目" },
          ],
        },
      ]);
    });
  });

  describe("返事を作れなかった回があるとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: {
          results: [
            result(0, "off-topic-movie", {
              success: false,
              error: "返事を作れなかった（LlmCallError）\n    at JudgeProvider.callApi",
            }),
          ],
        },
      };
    });

    test("落ちた回として、提供元のエラーの1行目を理由に読むこと", () => {
      expect(readReplyResults(results)).toEqual([
        {
          id: "off-topic-movie",
          runs: [
            {
              pass: false,
              output: undefined,
              failures: [{ rubric: "返事を作る", reason: "返事を作れなかった（LlmCallError）" }],
            },
          ],
        },
      ]);
    });
  });
});
