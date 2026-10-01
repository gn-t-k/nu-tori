import type { MealEntryMethod } from "./meal-entry-method";

export type Meal = {
  id: string;
  // 撮った時刻（食事の時刻）と、その時刻の UTC との時差
  eatenAt: Date;
  eatenAtUtcOffsetSeconds: number;
  // 送った時刻と、送ったときの端末のタイムゾーン（IANA 名）
  sentAt: Date;
  sentTimeZone: string;
  entryMethod: MealEntryMethod;
  // 並びが写真の並び順
  photoIds: readonly string[];
};
