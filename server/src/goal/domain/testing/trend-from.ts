import { addDays } from "../../../domain/add-days";

// 日ごとの体重の傾向を、from の日から順に並べる
export const trendFrom = (from: string, trendKgs: readonly number[]) =>
  trendKgs.map((trendKg, offset) => ({ calendarDay: addDays(from, offset), trendKg }));
