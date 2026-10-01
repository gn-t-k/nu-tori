import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Ingredient } from "../domain/ingredient";
import { toIngredientChangeResponse } from "./to-ingredient-change-response";

// サーバーだけが書く種類なので、端末からの書き込みは届かない（書き込みの型が never）
export const ingredientHttpKind: HttpRecordKind<Ingredient, never> = {
  writeTypes: [],
  toWrite: (write) => write,
  toChangeResponse: toIngredientChangeResponse,
};
