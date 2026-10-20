// 同期で扱う記録の種類の名前の一覧。名前を書くのはここだけで、種類の名前の型（RecordType）と、帳簿の表の列挙（sync-ledger-tables.ts）が引く。
// 何も import しない（表の宣言からも引けるようにするため）。種類を足すときは、名前の順に1行足す。
// 足すと、種類の登録簿（create-record-kinds.ts）と受け口の登録簿（http-record-kinds.ts）に行を足すまで、型検査が落ちる
export const recordTypes = [
  "account_settings",
  "ai_utterance",
  "daily_guide",
  "dish",
  "dish_estimation_status",
  "expenditure_estimate",
  "goal",
  "ingredient",
  "meal",
  "meal_estimation_status",
  "notice",
  "sent_text",
  "sent_text_status",
  "usual_weighing_time",
  "weekly_review",
  "weight_record",
  "weight_trend",
] as const;
