// Jev の確からしさのしきい値。#419 の「読み分け」の 0.5〜0.95 を 0.05 刻みで動かす
export const classificationThresholds = [
  0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95,
] as const;
