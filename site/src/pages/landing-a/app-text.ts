// アプリの部品の見本に出す数の書き方。アプリの NutritionText・GoalText・WeightAmountText（ios/NuToriCore）と同じにする
export const appText = {
  // 「1,850」。kcal と g は整数に丸める
  number: (value: number) => Math.round(value).toLocaleString("en-US"),
  kcal: (kcal: number) => `${appText.number(kcal)} kcal`,
  grams: (grams: number) => `${appText.number(grams)} g`,
  // 「−50 kcal」「+50 kcal」「0 kcal」
  signedKcal: (kcal: number) =>
    `${kcal > 0 ? "+" : kcal < 0 ? "−" : ""}${appText.kcal(Math.abs(kcal))}`,
  // 「70.0 kg」
  kg: (kg: number) => `${kg.toFixed(1)} kg`,
  // 「−0.3 kg」「+0.2 kg」「±0.0 kg」。見本の体重の変わり方の値で、アプリの画面には無い書き方
  signedKg: (kg: number) => `${kg > 0 ? "+" : kg < 0 ? "−" : "±"}${appText.kg(Math.abs(kg))}`,
};
