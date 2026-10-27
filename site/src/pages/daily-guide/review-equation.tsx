import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { kcal, kg } = formatExampleValue;

// 例の週に、ずれから推定消費カロリーを直した計算。筋（7日とも記録し、推定が高すぎる向きのずれが2週続いた）は daily-guide-example.ts が確かめる
export const ReviewEquation = () => {
  const review = dailyGuideExample.exampleReview;
  return (
    <div class="equation">
      <div class="eq-row">
        <span class="eq-label">ずれを1日あたりのカロリーにする</span>
        <span class="eq-value">
          約 {kg(review.deviationKg, 2)} kg × 7,700 kcal/kg ÷ 7 日 ＝ 1日 約{" "}
          {kcal(review.deviationKcalPerDay)} kcal
        </span>
      </div>
      <div class="eq-row">
        <span class="eq-label">そのうち動かす割合</span>
        <span class="eq-value">
          × {review.gain} ＝ 約 {kcal(review.adjustedKcal)}{" "}
          kcal（この週は、食事を7日とも記録し、推定が高すぎる向きのずれが2週続いたので）
        </span>
      </div>
      <div class="eq-row eq-result">
        <span class="eq-label">新しい推定消費カロリー</span>
        <span class="eq-value">
          {kcal(review.previousExpenditureKcal)} kcal − 約 {kcal(review.adjustedKcal)} kcal ＝{" "}
          <strong>{kcal(review.expenditureKcal)} kcal</strong>
        </span>
      </div>
    </div>
  );
};
