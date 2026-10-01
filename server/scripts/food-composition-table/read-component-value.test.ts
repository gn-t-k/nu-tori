import { beforeEach, describe, expect, test } from "vitest";
import { readComponentValue } from "./read-component-value";

describe("成分表のセルの値の読み方", () => {
  describe("数値のセルのとき", () => {
    let cell: number;
    beforeEach(() => {
      cell = 343;
    });

    test("その値を返すこと", () => {
      expect(readComponentValue(cell)).toBe(343);
    });
  });

  describe("数字が文字列で入っているとき（末尾の 0 を残した 0.20 など）", () => {
    let cell: string;
    beforeEach(() => {
      cell = "0.20";
    });

    test("その値を返すこと", () => {
      expect(readComponentValue(cell)).toBe(0.2);
    });
  });

  describe("Tr（微量）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "Tr";
    });

    test("0 を返すこと", () => {
      expect(readComponentValue(cell)).toBe(0);
    });
  });

  describe("(Tr)（推計値の微量）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "(Tr)";
    });

    test("0 を返すこと", () => {
      expect(readComponentValue(cell)).toBe(0);
    });
  });

  describe("(0)（推計値の 0）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "(0)";
    });

    test("0 を返すこと", () => {
      expect(readComponentValue(cell)).toBe(0);
    });
  });

  describe("(11.3)（括弧付きの推計値）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "(11.3)";
    });

    test("括弧を外したその値を返すこと", () => {
      expect(readComponentValue(cell)).toBe(11.3);
    });
  });

  describe("-（未測定など、値が無い）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "-";
    });

    test("不明として undefined を返すこと（0 にしない）", () => {
      expect(readComponentValue(cell)).toBeUndefined();
    });
  });

  describe("*（ヨウ素の「第3章参照」の印）のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "*";
    });

    test("本表に値が無いので、不明として undefined を返すこと", () => {
      expect(readComponentValue(cell)).toBeUndefined();
    });
  });

  describe("空のセルのとき", () => {
    let cell: null;
    beforeEach(() => {
      cell = null;
    });

    test("不明として undefined を返すこと", () => {
      expect(readComponentValue(cell)).toBeUndefined();
    });
  });

  describe("規定法による測定値の印（†）が付いているとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "20.3†";
    });

    test("印を外したその値を返すこと", () => {
      expect(readComponentValue(cell)).toBe(20.3);
    });
  });

  describe("知らない表記のとき", () => {
    let cell: string;
    beforeEach(() => {
      cell = "微量";
    });

    test("0 や不明に読み替えず、投げること", () => {
      expect(() => readComponentValue(cell)).toThrow("知らない表記");
    });
  });
});
