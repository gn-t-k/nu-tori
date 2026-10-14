import type { ProposalPace } from "./proposal-pace";
import type { WeightChangeDirection } from "./weight-change-direction";

// 目標案の速さ。開始の日の体重の傾向に対する、1週間に変わる割合。出荷後に調整する初期値
export const weeklyPaceRates = {
  lose: { gentle: 0.0025, standard: 0.005, hard: 0.0075 },
  gain: { gentle: 0.0015, standard: 0.003, hard: 0.005 },
} as const satisfies Record<WeightChangeDirection, Record<ProposalPace, number>>;
