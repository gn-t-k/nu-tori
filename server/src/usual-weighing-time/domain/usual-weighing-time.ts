import type { RecordId } from "../../domain/record-id";

// いつもの時刻。アカウントに1つで、値はその日の何分目（0〜1435、5 分単位）
export type UsualWeighingTime = { id: RecordId; minuteOfDay: number };
