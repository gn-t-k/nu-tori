// 送った文章の状態。行を持たず、読み分けと返事の流れの出来事から出す。
// 応答の状態（応答待ち・返事あり・回数切れ・作れなかった）と作れなかった理由は、返事の流れを足すときに足す（#419 の「同期」）
export type SentTextStatus = {
  // 読み分けの今の結果。pending は読み分けを待っている
  classification: "pending" | "meal" | "conversation";
};
