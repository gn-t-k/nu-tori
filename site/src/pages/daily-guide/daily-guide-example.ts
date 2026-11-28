import example from "./daily-guide-example.json";

// json は server/scripts/print-daily-guide-example.ts が書き出すので、手で書き換えない（server/AGENTS.md の「出し方のページと LP の例」）
export const dailyGuideExample = (() => {
  const [firstReview, secondReview, thirdReview, fourthReview] = example.reviews;
  const firstDay = example.days[0];
  const lastDay = example.days.at(-1);
  const plateauStart = example.plateau[0];
  // 4週ごとに並べているので、13 番めが1年後
  const plateauAfterOneYear = example.plateau[13];
  const plateauAfterTwoYears = example.plateau.at(-1);
  if (
    firstReview === undefined ||
    secondReview === undefined ||
    thirdReview === undefined ||
    fourthReview === undefined ||
    firstDay === undefined ||
    lastDay === undefined ||
    plateauStart === undefined ||
    plateauAfterOneYear === undefined ||
    plateauAfterTwoYears === undefined
  ) {
    throw new Error("出し方のページの例に、本文が使う日か週が無い");
  }

  // 本文は、この例の筋（1週目に体重の傾向が予想に反して増え、推定が高すぎる向きのずれになる、直す割合が週ごとに小さくなる、など）を文で書いている。
  // サーバーの決まりが変わって筋が変わったら、書き出しで気づけるように止め、本文を書き直す
  const assumptions = [
    ["見直しが4週ある", example.reviews.length === 4],
    [
      "食事を毎週7日とも記録した",
      example.reviews.every(({ recordedMealDayCount }) => recordedMealDayCount === 7),
    ],
    [
      "1週目は体重の傾向が増え、推定が高すぎる向きのずれ",
      firstReview.actualWeightChangeKg > 0 && firstReview.deviationKg < 0,
    ],
    [
      "1週目と2週目だけ、1週の変化の幅で止まる",
      firstReview.limitHits.includes("weekly_change") &&
        secondReview.limitHits.includes("weekly_change") &&
        thirdReview.limitHits.length === 0 &&
        fourthReview.limitHits.length === 0,
    ],
    [
      "1週目だけ、推定消費カロリーの動きが1回の上限で止まる",
      firstReview.hitAdjustmentLimit &&
        !secondReview.hitAdjustmentLimit &&
        !thirdReview.hitAdjustmentLimit &&
        !fourthReview.hitAdjustmentLimit,
    ],
    [
      "直す割合が週ごとに小さくなる",
      example.reviews.every(
        ({ gain }, index) => index === 0 || gain < (example.reviews[index - 1]?.gain ?? 0),
      ),
    ],
    ["4週目のあと、2年分を4週ごとに並べる", plateauAfterTwoYears.week - plateauStart.week === 104],
  ] as const;
  const broken = assumptions.filter(([, holds]) => !holds).map(([assumption]) => assumption);
  if (broken.length > 0) {
    throw new Error(`出し方のページの例が、本文の筋と合わなくなった: ${broken.join("、")}`);
  }

  return {
    ...example,
    // 本文と図の例に使う週。1週目は、ずれがいちばん大きく、直す割合もいちばん大きい週
    exampleReview: firstReview,
    lastReview: fourthReview,
    firstDay,
    lastDay,
    plateauStart,
    plateauAfterOneYear,
    plateauAfterTwoYears,
  };
})();
