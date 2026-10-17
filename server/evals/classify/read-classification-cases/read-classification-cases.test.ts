import { beforeEach, describe, expect, test } from "vitest";
import { readClassificationCases } from "./index";

// promptfoo の結果（-o の JSON）の1行の、読むところだけを持つ形。scores は間違いの種類ごとの score（1 で間違えた）
const result = (
  testIdx: number,
  text: string,
  outcome: { scores: number[] } | { error: string },
) => ({
  testIdx,
  vars: { text },
  error: "error" in outcome ? outcome.error : null,
  gradingResult:
    "error" in outcome ? null : { componentResults: outcome.scores.map((score) => ({ score })) },
});

describe("読み分けの評価の結果を、文章ごとに読む", () => {
  describe("同じ文章を何回か回し、promptfoo が回し終えた順に並べたとき", () => {
    let results: unknown;
    beforeEach(() => {
      // --repeat 2 の testIdx は、1つ目の文章が 0 と 1、2つ目が 2 と 3
      results = {
        results: {
          results: [
            result(2, "おはよう", { scores: [0, 1] }),
            result(0, "親子丼を食べた", { scores: [0, 0] }),
            result(3, "おはよう", { scores: [0, 0] }),
            result(1, "親子丼を食べた", { scores: [1, 0] }),
          ],
        },
      };
    });

    test("評価の組の順に、文章ごとに回した数と、間違えずに読めた回の数を読むこと", () => {
      expect(readClassificationCases(results)).toEqual([
        { id: "親子丼を食べた", passedRuns: 1, runCount: 2 },
        { id: "おはよう", passedRuns: 1, runCount: 2 },
      ]);
    });
  });

  describe("呼び出しに失敗した回があるとき", () => {
    let results: unknown;
    beforeEach(() => {
      results = {
        results: { results: [result(0, "親子丼を食べた", { error: "Haiku 5.5 を呼べなかった" })] },
      };
    });

    test("読めなかった回に数えること", () => {
      expect(readClassificationCases(results)).toEqual([
        { id: "親子丼を食べた", passedRuns: 0, runCount: 1 },
      ]);
    });
  });
});
