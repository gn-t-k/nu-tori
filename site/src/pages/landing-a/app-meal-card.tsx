import { match } from "ts-pattern";
import { AppChevron } from "./app-chevron";
import { appText } from "./app-text";
import type { ExampleMeal } from "./example-meals";

// アプリのタイムラインの食事のカード（ios/NuTori/Meal/MealCardView.swift）。下に料理の名前と kcal・P・F・C。
// 撮った食事は写真を上に 4:3 で出し、時刻はカードの外に置くので書かない（DESIGN.md の own-record-time）。
// 書いた食事は写真の場所を持たず、文章とその食事のかたまりの中で食べた時刻を書く
export const AppMealCard = ({
  meal,
  entry,
}: {
  meal: ExampleMeal;
  entry: { kind: "photo" } | { kind: "text"; eatenTime: string };
}) => (
  <div class="app-meal">
    {match(entry)
      .with({ kind: "photo" }, () => (
        <img src={meal.photo.src} alt={meal.photo.alt} width="800" height="600" loading="lazy" />
      ))
      .with({ kind: "text" }, () => null)
      .exhaustive()}
    <div class="app-meal-body">
      <div class="app-meal-text">
        <span class="app-meal-name">{meal.dish}</span>
        {match(entry)
          .with({ kind: "photo" }, () => null)
          .with({ kind: "text" }, ({ eatenTime }) => <span class="app-meal-time">{eatenTime}</span>)
          .exhaustive()}
        <span class="app-meal-nutrition">
          <b>{appText.kcal(meal.totals.energyKcal)}</b>
          <span>P {appText.grams(meal.totals.proteinG)}</span>
          <span>F {appText.grams(meal.totals.fatG)}</span>
          <span>C {appText.grams(meal.totals.carbohydrateG)}</span>
        </span>
      </div>
      <AppChevron />
    </div>
  </div>
);
