import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Dish } from "../domain/dish";
import { toDishChangeResponse } from "./to-dish-change-response";

// サーバーだけが書く種類なので、端末からの書き込みは届かない（書き込みの型が never）
export const dishHttpKind: HttpRecordKind<Dish, never> = {
  writeTypes: [],
  toWrite: (write) => write,
  toChangeResponse: toDishChangeResponse,
};
