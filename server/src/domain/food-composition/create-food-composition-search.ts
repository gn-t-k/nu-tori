import type { FoodCompositionEntry } from "./food-composition-entry";

// 成分表の食品を、材料の名前（と別名）から探す。メモリの中だけで動く
// 名前を字の組（2 文字。1 文字の語は 1 文字）に分け、尋ねた語の字の組が食品の名前と別名にどれだけ含まれるかで並べる。
// 字の組は、少ない食品にしか無いほど重く数える（「生」より「むね」のほうが食品を絞れる）
export const createFoodCompositionSearch = (entries: readonly FoodCompositionEntry[]) => {
  const gramsOfEntries = entries.map(
    (entry) => new Set([entry.name, ...entry.aliases].flatMap(toGrams)),
  );
  const documentFrequencies = new Map<string, number>();
  for (const grams of gramsOfEntries) {
    for (const gram of grams) {
      documentFrequencies.set(gram, (documentFrequencies.get(gram) ?? 0) + 1);
    }
  }
  const weightOf = (gram: string): number =>
    Math.log(1 + entries.length / (documentFrequencies.get(gram) ?? 0.5));
  const sumWeights = (grams: Iterable<string>): number => {
    let sum = 0;
    for (const gram of grams) {
      sum += weightOf(gram);
    }
    return sum;
  };

  const indexed = entries.map((entry, index) => {
    const grams = gramsOfEntries[index] ?? new Set<string>();
    return { entry, grams, weight: sumWeights(grams) };
  });
  const byFoodNumber = new Map(entries.map((entry) => [entry.foodNumber, entry]));

  return {
    // 点数の高い順に、最大 limit 件。点数は、尋ねた語の字の組のうち含まれる割合（重み付き）を第1に、
    // 食品の側の字の組のうち尋ねた語に含まれる割合を第2にする。同点は食品番号の順
    findCandidates: (query: string, limit: number): FoodCompositionEntry[] => {
      const queryGrams = new Set(toGrams(query));
      const queryWeight = sumWeights(queryGrams);
      if (queryWeight === 0) {
        return [];
      }
      return indexed
        .map(({ entry, grams, weight }) => {
          const shared = [...queryGrams].filter((gram) => grams.has(gram));
          const sharedWeight = sumWeights(shared);
          return {
            entry,
            coverage: sharedWeight / queryWeight,
            precision: sharedWeight / weight,
          };
        })
        .filter(({ coverage }) => coverage > 0)
        .toSorted(
          (a, b) =>
            b.coverage - a.coverage ||
            b.precision - a.precision ||
            compareFoodNumbers(a.entry.foodNumber, b.entry.foodNumber),
        )
        .slice(0, limit)
        .map(({ entry }) => entry);
    },
    findByFoodNumber: (foodNumber: string): FoodCompositionEntry | undefined =>
      byFoodNumber.get(foodNumber),
  };
};

// 全角半角をそろえ、ひらがなをカタカナにして、語の区切りの記号と空白で分けた各語を字の組にする
const toGrams = (text: string): string[] =>
  hiraganaToKatakana(text.normalize("NFKC").toLowerCase())
    .split(/[\s<>[\]()（）［］＜＞「」、,・･.。]+/u)
    .flatMap((word) => {
      const characters = Array.from(word);
      if (characters.length <= 1) {
        return characters;
      }
      return characters.slice(1).map((character, index) => `${characters[index]}${character}`);
    });

const hiraganaToKatakana = (text: string): string =>
  text.replaceAll(/[ぁ-ゖ]/gu, (character) =>
    String.fromCodePoint((character.codePointAt(0) ?? 0) + 0x60),
  );

// 食品番号は同じ桁数の数字なので、文字の並びで比べる（実行環境のロケールに左右されない）
const compareFoodNumbers = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);
