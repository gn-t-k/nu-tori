import { match } from "ts-pattern";
import { AppMealCard } from "./app-meal-card";
import { AppPfc } from "./app-pfc";
import { appText } from "./app-text";
import { exampleMeals, type ExampleMeal } from "./example-meals";

// 成分表の節の見本。写真を選ぶと、その写真から出る料理・材料・量・栄養の出どころが変わる。
// 食事ごとの中身は書き出しで全部描き、public/landing-a.js は選んだもの以外を隠すだけにする（スクリプトが動かなくても最初の食事は読める）
export const MealPhotoPicker = () => (
  <div class="lp-example" data-meal-picker>
    <div class="lp-segmented" role="group" aria-label="写真を選ぶ">
      {exampleMeals.map((meal, index) => (
        <button
          type="button"
          data-meal-key={meal.key}
          aria-pressed={index === 0 ? "true" : "false"}
        >
          {meal.dish}
        </button>
      ))}
    </div>
    {exampleMeals.map((meal, index) => (
      <div class="lp-example-panel" data-meal-panel={meal.key} hidden={index !== 0}>
        <AppMealCard meal={meal} entry={{ kind: "photo" }} />
        <MealTotals meal={meal} />
        <MealIngredients meal={meal} />
      </div>
    ))}
  </div>
);

// 食事の画面の合計（ios/NuTori/Meal/MealScreen.swift の totals）。kcal と P・F・C、その下に栄養の出どころの1行
const MealTotals = ({ meal }: { meal: ExampleMeal }) => (
  <div class="app-list app-meal-totals">
    <p class="app-meal-totals-kcal">
      <b>{appText.number(meal.totals.energyKcal)}</b> <span>kcal</span>
    </p>
    <AppPfc
      protein={appText.grams(meal.totals.proteinG)}
      fat={appText.grams(meal.totals.fatG)}
      carbohydrate={appText.grams(meal.totals.carbohydrateG)}
      replacedByScript={false}
    />
    <p class="app-secondary">{sourceLine(meal)}</p>
  </div>
);

// 料理の画面の「材料」（ios/NuTori/Dish/DishScreen.swift）。名前と、Primary の量と灰色の単位
const MealIngredients = ({ meal }: { meal: ExampleMeal }) => (
  <div>
    <p class="app-list-head">材料</p>
    <ul class="app-list">
      {meal.ingredients.map((ingredient) => (
        <li class="app-list-row">
          <span>{ingredient.name}</span>
          <span>
            <span class="app-editable">{ingredient.quantity}</span>
            {/^[A-Za-z]/.test(ingredient.unit) ? " " : ""}
            <span class="app-secondary">{ingredient.unit}</span>
          </span>
        </li>
      ))}
    </ul>
  </div>
);

// 「栄養の出どころ: 成分表 3・推定 1」。栄養成分表示・成分表・推定の順で、1種類だけなら数を書かない（ios/NuToriCore の NutrientSourceLine）
const sourceLine = (meal: ExampleMeal) => {
  const entries = sourceKinds.flatMap((kind) => {
    const count = meal.ingredients.filter((ingredient) => ingredient.source === kind).length;
    return count > 0 ? [{ kind, count }] : [];
  });
  const texts = entries.map(({ kind, count }) =>
    entries.length > 1 ? `${sourceName(kind)} ${count}` : sourceName(kind),
  );
  return `栄養の出どころ: ${texts.join("・")}`;
};

const sourceKinds = ["nutrition_label", "food_composition", "estimated"] as const;

const sourceName = (kind: (typeof sourceKinds)[number]) =>
  match(kind)
    .with("nutrition_label", () => "栄養成分表示")
    .with("food_composition", () => "成分表")
    .with("estimated", () => "推定")
    .exhaustive();
