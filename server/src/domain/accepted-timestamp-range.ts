// 端末が送る時刻（UNIX 時刻のミリ秒）の受け付ける範囲。2000-01-01 0:00 から 2100-01-01 0:00（UTC）まで。
// Date の表せる端まで通すと、土地の時刻・数える日・次の日の 0:00・何週か遡る計算が Date の外や5桁の年に出て、NaN や例外になる（#1062）。ありうる時刻に狭め、その手前で断る
export const acceptedTimestampRange = {
  minimum: Date.UTC(2000, 0, 1),
  maximum: Date.UTC(2100, 0, 1),
} as const;
