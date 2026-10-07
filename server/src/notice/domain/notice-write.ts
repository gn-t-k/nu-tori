import type { RecordId } from "../../domain/record-id";
import type { Notice, NoticeResponse } from "./notice";

// 端末から届く知らせの書き込み。種類は、受け付けるかを種類の decide が決めるため文字列で受ける
export type NoticeWrite = { id: RecordId } & (
  | {
      type: "create_notice";
      notice: Omit<Notice, "noticeType" | "response"> & { noticeType: string };
    }
  | { type: "respond_notice"; noticeId: RecordId; response: NoticeResponse }
);

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const noticeWriteTypes: readonly string[] = Object.keys({
  create_notice: true,
  respond_notice: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<NoticeWrite["type"], true>);
