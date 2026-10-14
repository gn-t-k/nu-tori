// 体重を変える目標の向き。維持は目標体重へ向かう速さを持たないので含めない
export const weightChangeDirections = ["lose", "gain"] as const;

export type WeightChangeDirection = (typeof weightChangeDirections)[number];
