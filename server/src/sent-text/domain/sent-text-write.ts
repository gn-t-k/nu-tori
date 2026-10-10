import type { RecordId } from "../../domain/record-id";
import type { SentText } from "./sent-text";

// 端末から届く送った文章の書き込み。送り直す書き込みは、断られても控えの kind で見分けられるよう、直す書き込みにせず操作ごとに分ける
export type SentTextWrite = { id: RecordId } & (
  | { type: "create_sent_text"; sentText: SentText }
  // 食事と読み分けた文章を、会話として送り直す（#419 の「会話として送り直す」）
  | { type: "resend_sent_text_as_conversation"; sentTextId: RecordId }
);

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const sentTextWriteTypes: readonly string[] = Object.keys({
  create_sent_text: true,
  resend_sent_text_as_conversation: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<SentTextWrite["type"], true>);
