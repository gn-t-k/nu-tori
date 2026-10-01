import nutrients from "../../../../shared/nutrients.json";

// 栄養の項目の名前。単位を名前に含む（energy_kcal, protein_g, ...）。正本は shared/nutrients.json
export type NutrientName = keyof typeof nutrients;

export const isNutrientName = (value: string): value is NutrientName =>
  Object.hasOwn(nutrients, value);
