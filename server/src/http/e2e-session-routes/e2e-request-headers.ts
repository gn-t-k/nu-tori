// 確かめのジョブが、開発用の環境の口に送るヘッダー。秘密の値は、サインインの口と時刻の差し替えで同じものを送る
export const e2eSecretHeader = "x-e2e-sign-in-secret";

// 目標の設定の要求を、この時刻（ISO 8601）に送ったことにする。開発用の環境で秘密の値が合うときだけ受け付ける
export const e2eRequestedAtHeader = "x-e2e-requested-at";
