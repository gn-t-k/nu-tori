import { dailyGuideExample } from "./daily-guide-example";
import { formatExampleValue } from "./format-example-value";

const { kcal, kg } = formatExampleValue;

// 例の週に、ずれから推定消費カロリーを直した計算。筋（最初の見直しで、推定が高すぎる向きのずれになり、動きが1回の上限で止まる）は daily-guide-example.ts が確かめる
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
          × {review.gain.toFixed(2)} ＝ 約 {kcal(review.adjustedKcal)}{" "}
          kcal（最初の見直しで、推定がまだ確かでないので、ずれの大きな割合を直します）
        </span>
      </div>
      <div class="eq-row">
        <span class="eq-label">1回で動かすのは 250 kcal まで</span>
        <span class="eq-value">250 kcal を越えるので、250 kcal にします</span>
      </div>
      <div class="eq-row eq-result">
        <span class="eq-label">新しい推定消費カロリー</span>
        <span class="eq-value">
          {kcal(review.previousExpenditureKcal)} kcal − 250 kcal ＝{" "}
          <strong>{kcal(review.expenditureKcal)} kcal</strong>
        </span>
      </div>
    </div>
  );
};
