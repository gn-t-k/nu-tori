import type { Write } from "./device-client";
import { generateRecordId } from "../src/domain/record-id";

// 手で記録した体重の書き込み。体重は作り話にする（公開リポジトリ）。減量の目標を決めたときと同じ値なので、続けて量っても目標体重に届かない
export const createWeightWrite = (measuredAt: number, timeZone: string): Write => ({
  id: generateRecordId(),
  type: "create_weight_record",
  weightRecord: {
    id: generateRecordId(),
    weightKg: 60.5,
    measuredAt,
    timeZone,
  },
});
