type CreateDishWrite = {
  id: string;
  type: "create_dish";
  dishId: string;
  mealId: string;
  name: string;
  positionInMeal: number;
};

// 料理を足す書き込み。料理の ID は端末が振る
export const createDishWrite = (
  mealId: string,
  fields: Partial<Pick<CreateDishWrite, "dishId" | "name" | "positionInMeal">> = {},
  overrides: { id?: string } = {},
): CreateDishWrite => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "create_dish",
  dishId: fields.dishId ?? crypto.randomUUID(),
  mealId,
  name: fields.name ?? "味噌汁",
  positionInMeal: fields.positionInMeal ?? 2,
});
