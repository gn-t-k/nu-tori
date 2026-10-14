// 身体データ。初めて目標を立てるときに、逆算できない人の推定消費カロリーを式で出すためだけに端末から受け取り、残さない。
// 年齢は端末が生年月日か生まれた年から出した歳。活動量は、歩数が読めた人は日ごとの歩数、読めなかった人は3択
export type BodyData = {
  sex: "male" | "female";
  heightCentimeters: number;
  ageYears: number;
  activity:
    | { type: "steps"; dailySteps: readonly { calendarDay: string; steps: number }[] }
    | { type: "level"; level: "sedentary" | "standing" | "active" };
};
