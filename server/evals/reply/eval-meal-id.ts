import { type RecordId, recordIdSchema } from "../../src/domain/record-id";

// 食事 ID。末尾の数で見分ける（1xx は記録の多い日、2xx は少ない日）
export const evalMealId = (n: number): RecordId =>
  recordIdSchema.parse(`7d1c2a4e-3b5f-4c8a-9e6d-${n.toString().padStart(12, "0")}`);
