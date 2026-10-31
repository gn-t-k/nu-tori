// LP の版 a の見本（「写真を選ぶ」とチャットの見本）の数字が本番の決まりとずれないよう、本番と同じドメイン層の関数で出す
import { loadFoodComposition } from "../src/domain/food-composition/load-food-composition";
import type { NutrientName } from "../src/domain/food-composition/nutrient-name";
import type { IngredientNutrientSource } from "../src/ingredient/domain/ingredient";
import { computeNutrientTotal } from "../src/ingredient/domain/compute-nutrient-total";

// 見本の食事。成分表は食品番号で引き、成分表に合うものが無い割り下だけを、AI が推定したことにした値（可食部 100 g あたり）で置く
type ExampleIngredient = {
  name: string;
  quantity: number;
  unit: string;
  edibleGramsPerUnit: number;
} & ({ foodNumber: string } | { estimated: Partial<Record<NutrientName, number>> });

type ExampleMeal = { key: string; dish: string; ingredients: ExampleIngredient[] };

const photoMeals: ExampleMeal[] = [
  {
    key: "oyakodon",
    dish: "親子丼",
    ingredients: [
      { name: "ご飯", foodNumber: "01088", quantity: 200, unit: "g", edibleGramsPerUnit: 1 },
      { name: "鶏もも肉", foodNumber: "11221", quantity: 80, unit: "g", edibleGramsPerUnit: 1 },
      { name: "卵", foodNumber: "12004", quantity: 1, unit: "個", edibleGramsPerUnit: 50 },
      {
        name: "割り下",
        estimated: { energy_kcal: 110, protein_g: 2, fat_g: 0, carbohydrate_g: 22 },
        quantity: 30,
        unit: "ml",
        edibleGramsPerUnit: 1,
      },
    ],
  },
  {
    key: "curry",
    dish: "カレーライス",
    ingredients: [
      { name: "ご飯", foodNumber: "01088", quantity: 200, unit: "g", edibleGramsPerUnit: 1 },
      { name: "牛肉（かた）", foodNumber: "11060", quantity: 50, unit: "g", edibleGramsPerUnit: 1 },
      { name: "じゃがいも", foodNumber: "02019", quantity: 50, unit: "g", edibleGramsPerUnit: 1 },
      { name: "たまねぎ", foodNumber: "06155", quantity: 40, unit: "g", edibleGramsPerUnit: 1 },
      { name: "にんじん", foodNumber: "06215", quantity: 20, unit: "g", edibleGramsPerUnit: 1 },
      { name: "カレールウ", foodNumber: "17051", quantity: 20, unit: "g", edibleGramsPerUnit: 1 },
      { name: "福神漬", foodNumber: "06143", quantity: 10, unit: "g", edibleGramsPerUnit: 1 },
    ],
  },
  {
    key: "onigiri",
    dish: "おにぎり",
    ingredients: [
      { name: "ご飯", foodNumber: "01088", quantity: 200, unit: "g", edibleGramsPerUnit: 1 },
      { name: "焼きのり", foodNumber: "09004", quantity: 2, unit: "g", edibleGramsPerUnit: 1 },
    ],
  },
];

// 書いた食事（「朝はお茶漬けを食べた」と送ったとき）
const textMeals: ExampleMeal[] = [
  {
    key: "ochazuke",
    dish: "お茶漬け",
    ingredients: [
      { name: "ご飯", foodNumber: "01088", quantity: 150, unit: "g", edibleGramsPerUnit: 1 },
      { name: "お茶漬けの素", foodNumber: "17125", quantity: 6, unit: "g", edibleGramsPerUnit: 1 },
      { name: "緑茶", foodNumber: "16037", quantity: 150, unit: "ml", edibleGramsPerUnit: 1 },
    ],
  },
];

const toCompositionIngredient = (ingredient: ExampleIngredient) => {
  if ("estimated" in ingredient) {
    const nutrientSource: IngredientNutrientSource = { type: "estimated" };
    return { ...ingredient, nutrientSource, nutrients: ingredient.estimated };
  }
  const food = loadFoodComposition().findByFoodNumber(ingredient.foodNumber);
  if (food === undefined) throw new Error(`成分表に無い食品番号: ${ingredient.foodNumber}`);
  const nutrientSource: IngredientNutrientSource = {
    type: "food_composition",
    foodNumber: ingredient.foodNumber,
  };
  return { ...ingredient, nutrientSource, nutrients: food.nutrients };
};

const computeExactTotal = (
  ingredients: ReturnType<typeof toCompositionIngredient>[],
  nutrient: NutrientName,
) => {
  const total = computeNutrientTotal(ingredients, nutrient);
  if (total.type !== "exactly") throw new Error(`${nutrient} に不明の材料が混じった`);
  return round(total.value, 2);
};

const round = (value: number, digits: number) => Number(value.toFixed(digits));

const toMealExample = ({ key, dish, ingredients }: ExampleMeal) => {
  const resolved = ingredients.map(toCompositionIngredient);
  return {
    key,
    dish,
    ingredients: resolved.map(({ name, quantity, unit, nutrientSource }) => ({
      name,
      quantity,
      unit,
      source: nutrientSource.type,
    })),
    totals: {
      energyKcal: computeExactTotal(resolved, "energy_kcal"),
      proteinG: computeExactTotal(resolved, "protein_g"),
      fatG: computeExactTotal(resolved, "fat_g"),
      carbohydrateG: computeExactTotal(resolved, "carbohydrate_g"),
    },
  };
};

console.log(
  JSON.stringify(
    {
      photoMeals: photoMeals.map(toMealExample),
      textMeals: textMeals.map(toMealExample),
    },
    null,
    2,
  ),
);
