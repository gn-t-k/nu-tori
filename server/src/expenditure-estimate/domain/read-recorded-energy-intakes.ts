import { computeCalendarDay } from "../../domain/compute-calendar-day";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeNutrientTotal } from "../../ingredient/domain/compute-nutrient-total";

// nu-tori の記録から出す、日ごとの食べた量。日は食事の時刻と時差での日。since のあたりの日は欠けることがあるので、呼ぶ側が範囲で絞る。
// 栄養の分からない材料は 0 と数える（その日は部分的な記録の日として、逆算が外す）
export const readRecordedEnergyIntakes = (
  stores: Pick<RecordKindStores, "meal" | "dish" | "ingredient">,
  since: Date,
): { calendarDay: string; kcal: number }[] => {
  const kcalOfDays = new Map<string, number>();
  for (const mealId of stores.meal.findIdsSentOrEatenSince(since)) {
    const meal = stores.meal.find(mealId);
    if (meal === undefined) {
      continue;
    }
    const ingredients = stores.dish
      .findIdsOfMeal(mealId)
      .flatMap((dishId) => stores.ingredient.findCurrentIdsOfDish(dishId))
      .flatMap((ingredientId) => {
        const ingredient = stores.ingredient.find(ingredientId);
        return ingredient === undefined ? [] : [ingredient];
      });
    const energy = computeNutrientTotal(ingredients, "energy_kcal");
    const calendarDay = computeCalendarDay(meal.eatenAt, meal.eatenAtUtcOffsetSeconds);
    kcalOfDays.set(
      calendarDay,
      (kcalOfDays.get(calendarDay) ?? 0) + (energy.type === "unknown" ? 0 : energy.value),
    );
  }
  return [...kcalOfDays].map(([calendarDay, kcal]) => ({ calendarDay, kcal }));
};
