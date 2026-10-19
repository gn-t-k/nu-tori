// 確かめのジョブが、開発用の環境の口に送るヘッダー
export const e2eRequestHeaders = {
  // 秘密の値。サインインの口と時刻の差し替えで同じものを送る
  signInSecret: "x-e2e-sign-in-secret",
  // 目標の設定の要求を、この時刻（ISO 8601）に送ったことにする。開発用の環境で秘密の値が合うときだけ受け付ける
  requestedAt: "x-e2e-requested-at",
} as const;
