// 1日の目安のカロリーの丸め。50 kcal 単位で、真ん中は切り上げる（浮動小数の誤差で切り下げない）
export const roundToFiftyKcal = (energyKcal: number): number =>
  Math.round(energyKcal / 50 + 1e-9) * 50;
