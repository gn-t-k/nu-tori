import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { UsualWeighingTime } from "../domain/usual-weighing-time";
import { toUsualWeighingTimeChangeResponse } from "./to-usual-weighing-time-change-response";

// サーバーだけが書く種類なので、端末からの書き込みは届かない（書き込みの型が never）
export const usualWeighingTimeHttpKind: HttpRecordKind<UsualWeighingTime, never> = {
  writeTypes: [],
  toWrite: (write) => write,
  toChangeResponse: toUsualWeighingTimeChangeResponse,
};
