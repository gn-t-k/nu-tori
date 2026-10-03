// 体重の傾向。始まり（最初の体重記録の日）から最後の体重記録の日まで、1日ずつ並ぶ。値は丸めない
export type WeightTrend = readonly { calendarDay: string; trendKg: number }[];
