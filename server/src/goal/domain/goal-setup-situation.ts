import type { BodyData } from "../../expenditure-estimate/domain/body-data";

// 目標の設定の要求がどれも載せる、端末の今の事情。使い始める前の摂取エネルギーと身体データは、計算に使ったら捨てる
export type GoalSetupSituation = {
  // 端末の今のタイムゾーン（IANA 名）。開始の日を決める
  timeZone: string;
  // 端末がヘルスケアから読んだ、使い始める前の日ごとの摂取エネルギー。立て直すときは使わない
  preUseEnergyIntakes: readonly { calendarDay: string; kcal: number }[];
  // 逆算できない人が、目標案から先の要求に添える
  bodyData: BodyData | undefined;
};
