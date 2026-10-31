// アプリの部品の見本に出す数の書き方。アプリの NutritionText・GoalText・WeightAmountText（ios/NuToriCore）と同じにする
export const appText = {
  // 「1,850」。kcal と g は整数に丸める
  number: (value: number) => Math.round(value).toLocaleString("en-US"),
  kcal: (kcal: number) => `${appText.number(kcal)} kcal`,
  grams: (grams: number) => `${appText.number(grams)} g`,
};
