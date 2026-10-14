// その日を含む目標と、その目標の1日の目安のうち、その日に当たるもの。目標が無ければ、その日は比べない。
// 日は YYYY-MM-DD の文字列で、文字列の順で比べる。端末にも同じ手順を置く（docs/agents/shared-rules.md の「その日の1日の目安」）
export const findDailyGuideForDay = <
  TGoal extends { id: string; startedOn: string; decidedAt: Date; endedOn: string | undefined },
  TDailyGuide extends { goalId: string; effectiveOn: string },
>(
  calendarDay: string,
  goals: readonly TGoal[],
  dailyGuides: readonly TDailyGuide[],
): { goal: TGoal; dailyGuide: TDailyGuide | undefined } | undefined => {
  // 同じ日に2回立て直すと、間の目標は開始の日と終わった日が同じになり、どの日も含まない
  const goal = findLatest(
    goals.filter(
      ({ startedOn, endedOn }) =>
        startedOn <= calendarDay && (endedOn === undefined || endedOn > calendarDay),
    ),
    (a, b) =>
      a.startedOn === b.startedOn
        ? a.decidedAt.getTime() > b.decidedAt.getTime()
        : a.startedOn > b.startedOn,
  );
  if (goal === undefined) {
    return undefined;
  }
  const dailyGuide = findLatest(
    dailyGuides.filter(
      ({ goalId, effectiveOn }) => goalId === goal.id && effectiveOn <= calendarDay,
    ),
    (a, b) => a.effectiveOn > b.effectiveOn,
  );
  return { goal, dailyGuide };
};

const findLatest = <TValue>(
  values: readonly TValue[],
  isLater: (a: TValue, b: TValue) => boolean,
): TValue | undefined =>
  values.reduce<TValue | undefined>(
    (latest, value) => (latest === undefined || isLater(value, latest) ? value : latest),
    undefined,
  );
