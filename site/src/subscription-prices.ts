// サブスクリプションの価格（円、税込）。特定商取引法に基づく表記と LP の料金の節がここを読む。
// App Store Connect の価格と同じにし、変えるときは App Store Connect と一緒に直す（docs/agents/privacy.md）
export const subscriptionPrices = {
  monthlyYen: 980,
  yearlyYen: 8800,
};

export const formatYen = (yen: number) => `${yen.toLocaleString("ja-JP")}円`;
