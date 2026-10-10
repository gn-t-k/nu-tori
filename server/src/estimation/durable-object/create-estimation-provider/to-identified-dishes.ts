import type { z } from "zod";
import type { IdentifiedDishes } from "../../domain/estimation-provider";
import type { identifiedDishSchema } from "./identified-dish-schema";

// 構造化出力で答えさせた料理を、ドメイン層の形にする（栄養成分表示の名前と値の組の並びを表に）
export const toIdentifiedDishes = (output: {
  dishes: readonly z.output<typeof identifiedDishSchema>[];
}): IdentifiedDishes => ({
  dishes: output.dishes.map((dish) => ({
    ...dish,
    ingredients: dish.ingredients.map(({ nutritionLabel, ...ingredient }) => ({
      ...ingredient,
      nutritionLabel:
        nutritionLabel === null
          ? undefined
          : {
              basisGrams: nutritionLabel.basisGrams,
              nutrients: Object.fromEntries(
                nutritionLabel.nutrients.map(({ nutrient, amount }) => [nutrient, amount]),
              ),
            },
    })),
  })),
});
