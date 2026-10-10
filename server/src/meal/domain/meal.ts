import type { RecordId } from "../../domain/record-id";
import type { MealEntryMethod } from "./meal-entry-method";

export type Meal = {
  id: RecordId;
  // 撮った時刻（食事の時刻）と、その時刻の UTC との時差
  eatenAt: Date;
  eatenAtUtcOffsetSeconds: number;
  // 送った時刻と、送ったときの端末のタイムゾーン（IANA 名）
  sentAt: Date;
  sentTimeZone: string;
  entryMethod: MealEntryMethod;
  // 並びが写真の並び順。文章の食事は写真を持たない
  photoIds: readonly RecordId[];
  // 文章の食事なら、作った送った文章の ID。写真の食事は undefined
  sentTextId: RecordId | undefined;
};
