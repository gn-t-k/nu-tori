// P・F・C の目安。係数は出荷後に調整する初期値
export const computeMacronutrientGuides = ({
  energyKcal,
  targetWeightKg,
}: {
  energyKcal: number;
  targetWeightKg: number;
}): { proteinG: number; fatG: number; carbohydrateG: number } => {
  // P は目標体重 1kg あたり 1.6g。1日の目安が少ないときに P だけで埋まらないよう、kcal で 35% までにする
  const proteinG = Math.min(
    roundToFiveGrams(1.6 * targetWeightKg),
    Math.floor((energyKcal * 0.35) / kcalPerGram.protein / 5) * 5,
  );
  const fatG = roundToFiveGrams((energyKcal * 0.25) / kcalPerGram.fat);
  // 丸めた P と F を引いた残りから出し、3つの kcal の和が1日の目安から離れないようにする
  const carbohydrateG = roundToFiveGrams(
    (energyKcal - proteinG * kcalPerGram.protein - fatG * kcalPerGram.fat) /
      kcalPerGram.carbohydrate,
  );
  return { proteinG, fatG, carbohydrateG };
};

const roundToFiveGrams = (grams: number): number => Math.round(grams / 5) * 5;

const kcalPerGram = { protein: 4, fat: 9, carbohydrate: 4 };
