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
  // 達成した減量・増量の目標だけが持つ
  achievement: GoalAchievement | undefined;
  // 期限の日が確定した減量・増量の目標だけが持つ
  deadlineConfirmation: GoalDeadlineConfirmation | undefined;
  // 閉じた目標だけが持つ
  closure: GoalClosure | undefined;
};

// 決めたときの目標。閉じたこと・達成・期限の日の確定は、あとで別の行で足す
export type DecidedGoal = Omit<Goal, "achievement" | "deadlineConfirmation" | "closure">;

export type GoalWeightChange = {
  // 期限（YYYY-MM-DD）
  deadlineOn: string;
  pacePlan: PacePlan;
};

// 減量・増量の目標の達成
export type GoalAchievement = {
  // 達成した日（YYYY-MM-DD）
  achievedOn: string;
  judgedAt: Date;
  // 判定を起こした要求のタイムゾーン
  timeZone: string;
};

// 減量・増量の目標の期限の日の確定
export type GoalDeadlineConfirmation = {
  // 期限の日の体重の傾向
  deadlineWeightTrendKg: number;
  confirmedAt: Date;
  // 確定を起こした要求のタイムゾーン
  timeZone: string;
};

// 目標を閉じたこと。終わった日は次の目標の開始の日
export type GoalClosure = {
  endedOn: string;
  nextGoalId: RecordId;
  // 終わり方。次の目標が期限後の維持の目標なら moved_to_maintenance、ほかは switched
  endReason: GoalEndReason;
};

// 目標の終わり方。立て直しによる切り替えと、期限後の維持に移ったこと
export const goalEndReasons = ["switched", "moved_to_maintenance"] as const;

export type GoalEndReason = (typeof goalEndReasons)[number];

// 速さの案。ゆるめ・標準・ハードと、自分で決めた目標体重
export const pacePlans = ["gentle", "standard", "hard", "custom"] as const;

export type PacePlan = (typeof pacePlans)[number];
