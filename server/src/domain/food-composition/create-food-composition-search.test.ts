import { beforeEach, describe, expect, test } from "vitest";
import { createFoodCompositionSearch } from "./create-food-composition-search";
import type { FoodCompositionEntry } from "./food-composition-entry";

const entry = (
  foodNumber: string,
  name: string,
  aliases: readonly string[] = [],
): FoodCompositionEntry => ({ foodNumber, name, aliases, nutrients: { energy_kcal: 100 } });

describe("材料の名前から成分表の候補を探す", () => {
  let entries: FoodCompositionEntry[];
  let search: ReturnType<typeof createFoodCompositionSearch>;
  beforeEach(() => {
    entries = [
      entry("01004", "えんばく　オートミール", ["オート", "オーツ"]),
      entry("06267", "ほうれんそう　葉　通年平均　生"),
      entry("06268", "ほうれんそう　葉　通年平均　ゆで"),
      entry("06269", "ほうれんそう　葉　冷凍　ゆで"),
      entry("11214", "＜鳥肉類＞　にわとり　［親・主品目］　むね　皮なし　生"),
      entry("11220", "＜鳥肉類＞　にわとり　［若どり・主品目］　むね　皮なし　生", ["ブロイラー"]),
      entry("11288", "＜鳥肉類＞　にわとり　［若どり・主品目］　むね　皮なし　焼き", [
        "ブロイラー",
      ]),
      entry("11224", "＜鳥肉類＞　にわとり　［若どり・主品目］　もも　皮なし　生", ["ブロイラー"]),
      entry("12004", "鶏卵　全卵　生"),
      entry("17007", "＜調味料類＞　（しょうゆ類）　こいくちしょうゆ"),
    ];
    search = createFoodCompositionSearch(entries);
  });

  describe("食品名の一部を含む語のとき", () => {
    test("その語を名前に含む食品を返すこと", () => {
      expect(search.findCandidates("オートミール", 5).map((e) => e.foodNumber)).toEqual(["01004"]);
    });
  });

  describe("別名と同じ語のとき", () => {
    test("別名を持つ食品を返すこと", () => {
      expect(search.findCandidates("オーツ", 5).map((e) => e.foodNumber)).toEqual(["01004"]);
    });
  });

  describe("名前をカタカナで持つ食品を、ひらがなで尋ねるとき", () => {
    test("かなの違いを区別せず、その食品を返すこと", () => {
      expect(search.findCandidates("おーとみーる", 5).map((e) => e.foodNumber)).toEqual(["01004"]);
    });
  });

  describe("名前をひらがなで持つ食品を、カタカナで尋ねるとき", () => {
    test("かなの違いを区別せず、その食品を返すこと", () => {
      expect(
        search
          .findCandidates("ホウレンソウ", 5)
          .map((e) => e.foodNumber)
          .toSorted(),
      ).toEqual(["06267", "06268", "06269"]);
    });
  });

  describe("調理の状態を含む語のとき", () => {
    test("その状態の食品を、そうでない食品より先に返すこと", () => {
      const foodNumbers = search.findCandidates("ほうれんそう 葉 ゆで", 3).map((e) => e.foodNumber);
      expect(foodNumbers.slice(0, 2).toSorted()).toEqual(["06268", "06269"]);
      expect(foodNumbers[2]).toBe("06267");
    });
  });

  describe("部位と状態を含む語のとき", () => {
    test("部位と状態の両方が合う食品を、そうでない食品より先に返すこと", () => {
      expect(search.findCandidates("むね肉 皮なし 生", 4).map((e) => e.foodNumber)).toEqual([
        "11214",
        "11220",
        "11288",
        "11224",
      ]);
    });
  });

  describe("名前の一部と別名にまたがる語のとき", () => {
    test("別名と名前の両方に合う食品を先に返すこと", () => {
      expect(search.findCandidates("ブロイラー むね 生", 2).map((e) => e.foodNumber)).toEqual([
        "11220",
        "11288",
      ]);
    });
  });

  describe("候補が上限より多いとき", () => {
    test("上限の数だけ返すこと", () => {
      expect(search.findCandidates("ほうれんそう", 2)).toHaveLength(2);
    });
  });

  describe("同じ点数の食品が並ぶとき", () => {
    beforeEach(() => {
      search = createFoodCompositionSearch([entry("20002", "あじ"), entry("20001", "あじ")]);
    });

    test("食品番号の小さい順に返すこと", () => {
      expect(search.findCandidates("あじ", 5).map((e) => e.foodNumber)).toEqual(["20001", "20002"]);
    });
  });

  describe("どの食品とも合う文字の無い語のとき", () => {
    test("候補を返さないこと", () => {
      expect(search.findCandidates("ガム", 5)).toEqual([]);
    });
  });

  describe("空の語のとき", () => {
    test("候補を返さないこと", () => {
      expect(search.findCandidates("  ", 5)).toEqual([]);
    });
  });

  describe("食品番号から引くとき", () => {
    test("その食品を返すこと", () => {
      expect(search.findByFoodNumber("12004")?.name).toBe("鶏卵　全卵　生");
    });

    test("無い食品番号なら undefined を返すこと", () => {
      expect(search.findByFoodNumber("99999")).toBeUndefined();
    });
  });
});
