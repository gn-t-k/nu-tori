import { beforeEach, describe, expect, test } from "vitest";
import { readAliases } from "./read-aliases";

describe("備考から別名を読む", () => {
  describe("備考が空のとき", () => {
    let remarks: null;
    beforeEach(() => {
      remarks = null;
    });

    test("別名が無いこと", () => {
      expect(readAliases(remarks)).toEqual([]);
    });
  });

  describe("別名が1行に読点で並んでいるとき", () => {
    let remarks: string;
    beforeEach(() => {
      remarks = "別名： オート、オーツ";
    });

    test("1つずつに分けて返すこと", () => {
      expect(readAliases(remarks)).toEqual(["オート", "オーツ"]);
    });
  });

  describe("別名のほかの行もあるとき", () => {
    let remarks: string;
    beforeEach(() => {
      remarks = "※ 耳の割合： 45 %\r\n別名：サンドイッチ用食パン\r\n食物繊維：AOAC2011.25法";
    });

    test("別名の行だけを読むこと", () => {
      expect(readAliases(remarks)).toEqual(["サンドイッチ用食パン"]);
    });
  });

  describe("別名の行が無いとき", () => {
    let remarks: string;
    beforeEach(() => {
      remarks = "廃棄部位： 頭部、骨、ひれ等";
    });

    test("別名が無いこと", () => {
      expect(readAliases(remarks)).toEqual([]);
    });
  });
});
