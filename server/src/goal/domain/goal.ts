import type { RecordId } from "../../domain/record-id";

// 目標。ID はサーバーが振る。向きは値で持たず、computeGoalDirection で出す
export type Goal = {
  id: RecordId;
  // 開始の日（YYYY-MM-DD）
  startedOn: string;
  // 開始の日以前で最も新しい体重の傾向
  startingWeightTrendKg: number;
  targetWeightKg: number;
  decidedAt: Date;
  // 決める要求のタイムゾーン
  timeZone: string;
  // 減量・増量の目標だけが持つ。無ければ維持
  weightChange: GoalWeightChange | undefined;
  // 閉じた目標だけが持つ
  closure: GoalClosure | undefined;
};

export type GoalWeightChange = {
  // 期限（YYYY-MM-DD）
  deadlineOn: string;
  pacePlan: PacePlan;
};

// 目標を閉じたこと。終わった日は次の目標の開始の日
export type GoalClosure = {
  endedOn: string;
  nextGoalId: RecordId;
};

// 速さの案。ゆるめ・標準・ハードと、自分で決めた目標体重
export const pacePlans = ["gentle", "standard", "hard", "custom"] as const;

export type PacePlan = (typeof pacePlans)[number];
