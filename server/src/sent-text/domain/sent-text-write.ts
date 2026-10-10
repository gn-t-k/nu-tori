import type { RecordId } from "../../domain/record-id";
import type { SentText } from "./sent-text";

// 端末から届く送った文章の書き込み
export type SentTextWrite = { id: RecordId } & { type: "create_sent_text"; sentText: SentText };

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const sentTextWriteTypes: readonly string[] = Object.keys({
  create_sent_text: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<SentTextWrite["type"], true>);
