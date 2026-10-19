import { addDays } from "../../domain/add-days";

// from から count 日の日付
export const daysFrom = (from: string, count: number): string[] =>
  Array.from({ length: count }, (_, offset) => addDays(from, offset));
