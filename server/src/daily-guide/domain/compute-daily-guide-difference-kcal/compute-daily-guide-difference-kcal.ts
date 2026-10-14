// 大変さのひとことに出す、1日の目安と推定消費カロリーの差。少ないときは負。1日の目安と同じ 50 kcal 単位にする
export const computeDailyGuideDifferenceKcal = ({
  expenditureKcal,
  dailyGuideEnergyKcal,
}: {
  expenditureKcal: number;
  dailyGuideEnergyKcal: number;
}): number => {
  const differenceKcal = Math.round((dailyGuideEnergyKcal - expenditureKcal) / 50) * 50;
  // -0 を返すと、応答の JSON と等しさの比べ方で 0 と食い違う
  return differenceKcal === 0 ? 0 : differenceKcal;
};
