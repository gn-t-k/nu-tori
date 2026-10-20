import { floatingPointTolerance } from "../../domain/floating-point-tolerance";

// 0.1kg 単位に丸める。0.1kg の倍数に浮動小数の誤差が乗った値（58.199999…）を、隣の 0.1kg へ送らない
export const roundToTenthKg = (weightKg: number, rounding: "ceil" | "floor" | "round"): number => {
  const tolerance = { ceil: -floatingPointTolerance, floor: floatingPointTolerance, round: 0 }[
    rounding
  ];
  return Math[rounding](weightKg * 10 + tolerance) / 10;
};
