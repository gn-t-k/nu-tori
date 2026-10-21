import { beforeEach, describe, expect, test } from "vitest";
import cases from "./cases.json";

// 読み分けの評価の組（仕様 #419 の「読み分け」）。promptfoo の tests の形で、正解を開発者が確かめる。
describe("読み分けの評価の組", () => {
  describe("組の全体", () => {
    test("決めた数だけあること", () => {
      expect(cases).toHaveLength(80);
    });

    test("文章が重ならないこと", () => {
      expect(new Set(cases.map(({ vars }) => vars.text)).size).toBe(cases.length);
    });

    test("文章が、受け付ける送った文章と同じく、前後の空白を除いて 1〜500 字であること", () => {
      const outOfRange = cases.filter(({ vars }) => {
        const length = vars.text.trim().length;
        return length < 1 || length > 500;
      });
      expect(outOfRange).toEqual([]);
    });
  });

  describe("食事が正解の境目", () => {
    describe("食べた・飲んだもの（今か過去）", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "ate");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(18);
      });

      test("正解がすべて食事であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "meal")).toBe(true);
      });
    });

    describe("問いが混ざった食事", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "ate_with_question");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(10);
      });

      test("正解がすべて食事であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "meal")).toBe(true);
      });
    });

    describe("「コーヒー」のような語だけのもの", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "bare_word");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(10);
      });

      test("正解がすべて食事であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "meal")).toBe(true);
      });
    });
  });

  describe("会話が正解の境目", () => {
    describe("これから食べるもの", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "will_eat");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(10);
      });

      test("正解がすべて会話であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "chat")).toBe(true);
      });
    });

    describe("記録の直し", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "correction");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(10);
      });

      test("正解がすべて会話であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "chat")).toBe(true);
      });
    });

    describe("食べていないこと", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "did_not_eat");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(10);
      });

      test("正解がすべて会話であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "chat")).toBe(true);
      });
    });

    describe("食事を伝えていない問いや相談", () => {
      let boundaryCases: typeof cases;
      beforeEach(() => {
        boundaryCases = cases.filter(({ vars }) => vars.boundary === "question");
      });

      test("決めた数だけあること", () => {
        expect(boundaryCases).toHaveLength(12);
      });

      test("正解がすべて会話であること", () => {
        expect(boundaryCases.every(({ vars }) => vars.expected === "chat")).toBe(true);
      });
    });
  });
});
