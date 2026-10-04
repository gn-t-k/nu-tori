import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Ingredient } from "../domain/ingredient";
import { ingredientRecordSchema } from "./ingredient-record-schema";
import { toIngredientRecord } from "./to-ingredient-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const ingredientHttpKind: HttpRecordKind<Ingredient, never, typeof ingredientRecordSchema> =
  {
    writes: undefined,
    recordSchema: ingredientRecordSchema,
    toRecord: toIngredientRecord,
  };
