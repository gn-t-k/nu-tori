import { match } from "ts-pattern";
import { AppChevron } from "./app-chevron";
import { AppPfc } from "./app-pfc";
import { appText } from "./app-text";
import { JsonScript } from "./json-script";
import examples from "./landing-a-examples.json";

// 目安の節の見本。先週の食べた量・体重の変わり方・目標を動かすと、アプリの「1日の目安が変わりました」の知らせが変わる。
// 見直しの数字は server/scripts/print-landing-a-examples.ts がサーバーの見直しの関数で出す。文はここで書き出しのときに全部作り、
// public/landing-a.js は選んだ組の文を入れ替えるだけにする（スクリプトが動かなくても、最初の組の知らせは読める）
export const ReviewExample = () => {
  // 最初に見せる組: 1,900 kcal 食べて体重が変わらず、3 kg 減らす目標
  const initialIntakeIndex = review.intakeOptionsKcal.indexOf(1900);
  const initialWeightChangeIndex = review.weightChangeOptionsKg.indexOf(0);
  const initialGoalIndex = goals.findIndex((goal) => goal.key === "lose-3kg");
  const initial =
    states.notices[initialGoalIndex]?.[initialIntakeIndex]?.[initialWeightChangeIndex];
  const initialIntake = states.intakeLabels[initialIntakeIndex];
  const initialWeightChange = states.weightChangeLabels[initialWeightChangeIndex];
  const initialPreviousGuide = states.previousGuides[initialGoalIndex];
  if (
    initial === undefined ||
    initialIntake === undefined ||
    initialWeightChange === undefined ||
    initialPreviousGuide === undefined
  ) {
    throw new Error("目安の見本の最初の組が、書き出した見直しに無い");
  }
  return (
    <div class="lp-example" data-review-example>
      <div class="lp-control">
        <label for="review-intake">
          先週、1日に食べた量（平均）<output data-review-intake-label>{initialIntake}</output>
        </label>
        <input
          type="range"
          id="review-intake"
          min="0"
          max={String(review.intakeOptionsKcal.length - 1)}
          step="1"
          value={String(initialIntakeIndex)}
          aria-valuetext={initialIntake}
          data-review-intake
        />
      </div>
      <div class="lp-control">
        <label for="review-weight-change">
          先週、体重が変わった量
          <output data-review-weight-change-label>{initialWeightChange}</output>
        </label>
        <input
          type="range"
          id="review-weight-change"
          min="0"
          max={String(review.weightChangeOptionsKg.length - 1)}
          step="1"
          value={String(initialWeightChangeIndex)}
          aria-valuetext={initialWeightChange}
          data-review-weight-change
        />
      </div>
      <div class="lp-segmented" role="group" aria-label="目標">
        {goals.map((goal, index) => (
          <button
            type="button"
            data-review-goal={String(index)}
            aria-pressed={index === initialGoalIndex ? "true" : "false"}
          >
            {goalLabel(goal)}
          </button>
        ))}
      </div>
      {/* 1日の目安の変更の知らせ（ios/NuTori/DailyGuide/DailyGuideChangeNoticeCard.swift）。時刻は見本 */}
      <div class="app-card app-notice" aria-live="polite">
        <p class="app-notice-head">
          <b>1日の目安が変わりました</b>
          <span class="app-secondary">7:02</span>
        </p>
        <p class="app-notice-value">
          <span class="app-notice-energy" data-review-energy>
            {initial.energy}
          </span>
          <span class="app-secondary" data-review-change>
            {initial.change}
          </span>
        </p>
        <div class="app-secondary">
          <AppPfc
            protein={initial.protein}
            fat={initial.fat}
            carbohydrate={initial.carbohydrate}
            replacedByScript
          />
        </div>
        <p class="app-secondary" data-review-reason>
          {initial.reason}
        </p>
        <span class="app-notice-link">
          目標
          <AppChevron />
        </span>
      </div>
      <p class="lp-fine">
        見本の人: 先週の月曜に体重{" "}
        <span class="lp-nowrap">{appText.kg(review.startingWeightTrendKg)}</span>{" "}
        で目標を立て（減らすときの期限は{review.goalWeeks}週）、1日に使うカロリーを{" "}
        <span class="lp-nowrap">{appText.kcal(review.previousExpenditureKcal)}</span>{" "}
        と見積もりました。先週の目安は{" "}
        <span class="lp-nowrap" data-review-previous-guide>
          {initialPreviousGuide}
        </span>{" "}
        で、食事は{review.recordedMealDayCount}
        日とも記録しています。体重が変わった量は、日々の上下をならした値です。計算はアプリと同じです（
        <a href="/daily-guide">1日の目安の出し方</a>）。
      </p>
      <JsonScript type="application/json" value={states} />
    </div>
  );
};

const review = examples.review;

// 見本の目標は、保つか減らすかだけ
const isExampleDirection = (direction: string): direction is "maintain" | "lose" =>
  direction === "maintain" || direction === "lose";

// サーバーの DailyGuideMainReason
const isMainReason = (reason: string): reason is "expenditure_change" | "balance_change" =>
  reason === "expenditure_change" || reason === "balance_change";

// JSON から読んだ向きと主な理由は string の型になるので、ここで絞り、下の分け方を網羅で閉じる
const goals = review.goals.map((goal) => {
  const direction = goal.direction;
  if (!isExampleDirection(direction)) {
    throw new Error(`目安の見本に無い目標の向き: ${direction}`);
  }
  const outcomes = goal.outcomes.map((row) =>
    row.map((outcome) => {
      const mainReason = outcome.mainReason;
      if (!isMainReason(mainReason)) {
        throw new Error(`目安の見本に無い主な理由: ${mainReason}`);
      }
      return { ...outcome, mainReason };
    }),
  );
  return { ...goal, direction, outcomes };
});
type Goal = (typeof goals)[number];
type Outcome = Goal["outcomes"][number][number];

const goalLabel = (goal: Goal) =>
  match(goal.direction)
    .with("maintain", () => "保つ")
    .with("lose", () => `${review.startingWeightTrendKg - goal.targetWeightKg} kg 減らす`)
    .exhaustive();

// 知らせの理由の文（ios/NuToriCore/Sources/NuToriCore/DailyGuide/DailyGuideChangeReason.swift の text）。見本の人は目標に届かず、期限も過ぎない
const reasonText = (goal: Goal, outcome: Outcome): string => {
  const previousExpenditureKcal = review.previousExpenditureKcal;
  return match(outcome.mainReason)
    .with(
      "expenditure_change",
      () =>
        `推定消費カロリーが ${appText.number(previousExpenditureKcal)} から ${appText.kcal(outcome.expenditureKcal)} に${outcome.expenditureKcal < previousExpenditureKcal ? "下がった" : "上がった"}ためです。`,
    )
    .with("balance_change", () => balanceReasonText(goal, outcome))
    .exhaustive();
};

// 1日の目安と推定消費カロリーの差が変わったときの文。差が前の週より広がったかで分ける
const balanceReasonText = (goal: Goal, outcome: Outcome): string => {
  const difference = outcome.guideKcal - outcome.expenditureKcal;
  const gapWidened =
    Math.abs(difference) > Math.abs(goal.previousGuideKcal - review.previousExpenditureKcal);
  return match(goal.direction)
    .with("lose", () =>
      gapWidened
        ? "期限に間に合うよう、1日の目安を推定消費カロリーよりさらに下げたためです。"
        : "体重が予定より早く減っているので、1日の目安を推定消費カロリーに近づけたためです。",
    )
    .with("maintain", () => {
      const target = appText.kg(goal.targetWeightKg);
      if (!gapWidened) {
        return `体重の傾向が ${target} に近づいたので、1日の目安を推定消費カロリーに近づけたためです。`;
      }
      return difference < 0
        ? `体重の傾向が ${target} を上回っているので、1日の目安を推定消費カロリーより下げたためです。`
        : `体重の傾向が ${target} を下回っているので、1日の目安を推定消費カロリーより上げたためです。`;
    })
    .exhaustive();
};

// notices は [目標][食べた量][体重が変わった量] の順に、知らせに入れる文を並べる。public/landing-a.js が名前で読む
const states = {
  // 目標ごとの先週の1日の目安。見本の注記に、選んだ目標の分だけ入れる
  previousGuides: goals.map((goal) => appText.kcal(goal.previousGuideKcal)),
  intakeLabels: review.intakeOptionsKcal.map((kcal) => appText.kcal(kcal)),
  weightChangeLabels: review.weightChangeOptionsKg.map((kg) => appText.signedKg(kg)),
  notices: goals.map((goal) =>
    goal.outcomes.map((row) =>
      row.map((outcome) => ({
        energy: appText.kcal(outcome.guideKcal),
        change: appText.signedKcal(outcome.guideKcal - goal.previousGuideKcal),
        protein: appText.grams(outcome.proteinG),
        fat: appText.grams(outcome.fatG),
        carbohydrate: appText.grams(outcome.carbohydrateG),
        reason: reasonText(goal, outcome),
      })),
    ),
  ),
};
