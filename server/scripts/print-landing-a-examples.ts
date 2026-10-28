// LP の版 a の見本（「写真を選ぶ」と「動かすと変わる」）の数字が本番の決まりとずれないよう、本番と同じドメイン層の関数で出す
import { addDays } from "../src/domain/add-days";
import { daysPerWeek } from "../src/domain/days-per-week";
import { countDaysInclusive } from "../src/goal/domain/accepted-deadline/count-days-inclusive";
import { classifyGoal } from "../src/goal/domain/classify-goal";
import { toRequiredPaceGoalFromDay } from "../src/goal/domain/to-required-pace-goal-from-day";
import { computeDailyGuideEnergy } from "../src/daily-guide/domain/compute-daily-guide-energy";
import { computeReviewedDailyGuide } from "../src/daily-guide/domain/compute-reviewed-daily-guide";
import type { DailyGuideGoal } from "../src/daily-guide/domain/daily-guide-goal";
import { loadFoodComposition } from "../src/domain/food-composition/load-food-composition";
import type { NutrientName } from "../src/domain/food-composition/nutrient-name";
import type { IngredientNutrientSource } from "../src/ingredient/domain/ingredient";
import { computeNutrientTotal } from "../src/ingredient/domain/compute-nutrient-total";
import { computeReviewedExpenditure } from "../src/weekly-review/domain/compute-reviewed-expenditure";

// 見本の食事。成分表は食品番号で引き、成分表に合うものが無い割り下だけを、AI が推定したことにした値（可食部 100 g あたり）で置く
type ExampleIngredient = {
  name: string;
  quantity: number;
  unit: string;
  edibleGramsPerUnit: number;
} & ({ foodNumber: string } | { estimated: Partial<Record<NutrientName, number>> });

type ExampleMeal = { key: string; dish: string; ingredients: ExampleIngredient[] };

// 写真の食事
const meals: ExampleMeal[] = [
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

// 見直しの見本。月曜に体重の傾向 70.0 kg で目標を立て、推定消費カロリー 2,100 kcal から1日の目安を出した人の、次の月曜の最初の見直し。
// その週は食事を7日とも記録した。目標は、保つ・12週で 3 kg 減らす・12週で 6 kg 減らす（週 0.25 kg と 0.5 kg）の3つから選ぶ
const startedOn = "2026-01-05"; // 月曜
const reviewedMonday = addDays(startedOn, daysPerWeek);
const startingWeightTrendKg = 70;
const previousExpenditureKcal = 2100;
const goalWeeks = 12;
const deadlineOn = addDays(startedOn, goalWeeks * daysPerWeek - 1);
const goals = [
  { key: "maintain", targetWeightKg: startingWeightTrendKg, weightChange: undefined },
  ...[3, 6].map((lossKg) => ({
    key: `lose-${lossKg}kg`,
    targetWeightKg: startingWeightTrendKg - lossKg,
    weightChange: { deadlineOn, pacePlan: "custom" } as const,
  })),
].map((goal) => ({ ...goal, startingWeightTrendKg }));
const intakeOptionsKcal = Array.from({ length: 9 }, (_, i) => 1600 + i * 100);
const weightChangeOptionsKg = Array.from({ length: 10 }, (_, i) => round(-0.6 + i * 0.1, 1));

// 目標を立てたときの1日の目安の計算に渡す形。案の計算で決まった向きと日数を、置き場の目標から出す
const toDailyGuideGoal = (goal: (typeof goals)[number]): DailyGuideGoal => {
  const classified = classifyGoal(goal);
  return classified.direction === "maintain"
    ? { direction: "maintain", targetWeightKg: goal.targetWeightKg }
    : {
        direction: classified.direction,
        startingWeightTrendKg: goal.startingWeightTrendKg,
        targetWeightKg: goal.targetWeightKg,
        daysFromStartToDeadline: countDaysInclusive(startedOn, classified.weightChange.deadlineOn),
      };
};

const reviewExample = {
  startingWeightTrendKg,
  previousExpenditureKcal,
  goalWeeks,
  recordedMealDayCount: daysPerWeek,
  intakeOptionsKcal,
  weightChangeOptionsKg,
  goals: goals.map((goal) => {
    const previousGuideKcal = computeDailyGuideEnergy({
      expenditureKcal: previousExpenditureKcal,
      goal: toDailyGuideGoal(goal),
    }).energyKcal;
    return {
      key: goal.key,
      direction: classifyGoal(goal).direction,
      targetWeightKg: goal.targetWeightKg,
      previousGuideKcal,
      // intakeOptionsKcal の順に、weightChangeOptionsKg の順の見直しを並べる
      outcomes: intakeOptionsKcal.map((averageEnergyIntakeKcal) =>
        weightChangeOptionsKg.map((actualWeightChangeKg) => {
          const reviewed = computeReviewedExpenditure({
            previousExpenditureKcal,
            averageEnergyIntakeKcal,
            recordedMealDayCount: daysPerWeek,
            actualWeightChangeKg,
            previousWeeks: [],
          });
          const guide = computeReviewedDailyGuide({
            expenditureKcal: reviewed.expenditureKcal,
            previous: { energyKcal: previousGuideKcal, expenditureKcal: previousExpenditureKcal },
            goal: toRequiredPaceGoalFromDay(goal, {
              firstDay: reviewedMonday,
              weightTrendKg: startingWeightTrendKg + actualWeightChangeKg,
            }),
          });
          return {
            expenditureKcal: reviewed.expenditureKcal,
            guideKcal: guide.energyKcal,
            proteinG: guide.proteinG,
            fatG: guide.fatG,
            carbohydrateG: guide.carbohydrateG,
            mainReason: guide.mainReason,
          };
        }),
      ),
    };
  }),
};

console.log(
  JSON.stringify(
    {
      meals: meals.map(toMealExample),
      textMeals: textMeals.map(toMealExample),
      review: reviewExample,
    },
    null,
    2,
  ),
);
