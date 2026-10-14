// 開始の日は端末の今日。立て直すとき、西へ移って今日が今の目標の開始の日より前になっても、開始の日を戻さない
export const decideGoalStartDay = ({
  today,
  currentGoalStartDay,
}: {
  today: string;
  // 初めて目標を立てるときは、今の目標が無い
  currentGoalStartDay: string | undefined;
}): string =>
  currentGoalStartDay !== undefined && today < currentGoalStartDay ? currentGoalStartDay : today;
