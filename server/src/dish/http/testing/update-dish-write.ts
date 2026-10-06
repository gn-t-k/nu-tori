type UpdateDishWrite = {
  id: string;
  type: "update_dish";
  dishId: string;
  name: string;
  quantity?: {
    value: number;
    proportionedIngredients: { ingredientId: string; quantity: number }[];
  };
};

// 量を省くと、名前だけを直す書き込みになる
export const updateDishWrite = (
  dishId: string,
  fields: Pick<UpdateDishWrite, "name" | "quantity">,
  overrides: { id?: string } = {},
): UpdateDishWrite => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "update_dish",
  dishId,
  ...fields,
});
