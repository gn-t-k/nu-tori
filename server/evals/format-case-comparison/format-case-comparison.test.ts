import { beforeEach, describe, expect, test } from "vitest";
import { formatCaseComparison } from "./index";

type ComparedRun = Parameters<typeof formatCaseComparison>[0];

describe("2つの版の評価の結果を、場面ごとに並べる", () => {
  describe("両方の版に同じ場面があるとき", () => {
    let base: ComparedRun;
    let head: ComparedRun;
    beforeEach(() => {
      base = {
        label: "main（1111111）",
        cases: [
          { id: "medical-kidney", passedRuns: 1, runCount: 3 },
          { id: "off-topic-movie", passedRuns: 3, runCount: 3 },
          { id: "preset-feedback-rich", passedRuns: 3, runCount: 3 },
        ],
      };
      head = {
        label: "HEAD（2222222）",
        cases: [
          { id: "medical-kidney", passedRuns: 3, runCount: 3 },
          { id: "off-topic-movie", passedRuns: 2, runCount: 3 },
          { id: "preset-feedback-rich", passedRuns: 3, runCount: 3 },
        ],
      };
    });

    test("場面ごとに両方の通った回を並べ、上がった・下がった場面に印を付け、すべての回で通った場面の数で締めること", () => {
      expect(formatCaseComparison(base, head)).toBe(
        [
          "| 場面 | main（1111111） | HEAD（2222222） | |",
          "|---|---|---|---|",
          "| medical-kidney | 1/3 | 3/3 | ↑ |",
          "| off-topic-movie | 3/3 | 2/3 | ↓ |",
          "| preset-feedback-rich | 3/3 | 3/3 | |",
          "| すべての回で通った場面 | 2/3 | 2/3 | |",
        ].join("\n"),
      );
    });
  });

  describe("片方の版にしか無い場面があるとき", () => {
    let base: ComparedRun;
    let head: ComparedRun;
    beforeEach(() => {
      base = { label: "main", cases: [{ id: "old-case", passedRuns: 1, runCount: 1 }] };
      head = { label: "HEAD", cases: [{ id: "new-case", passedRuns: 0, runCount: 1 }] };
    });

    test("比べる版の場面を先に、もとの版にしか無い場面を後ろに並べ、無いほうを「—」にすること", () => {
      expect(formatCaseComparison(base, head)).toBe(
        [
          "| 場面 | main | HEAD | |",
          "|---|---|---|---|",
          "| new-case | — | 0/1 | |",
          "| old-case | 1/1 | — | |",
          "| すべての回で通った場面 | 1/1 | 0/1 | |",
        ].join("\n"),
      );
    });
  });
});
