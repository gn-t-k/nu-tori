import type { RecordId } from "../../domain/record-id";
import type { NoticeResponse } from "./notice";

// 端末から届く知らせの書き込み。種類と対象の日付は、受け付けるかを種類の decide が決めるため、
// 種類は文字列で、対象の日付は種類によらず有るか無いかで受ける
export type NoticeWrite = { id: RecordId } & (
  | {
      type: "create_notice";
      notice: {
        id: RecordId;
        noticeType: string;
        issuedAt: Date;
        timeZone: string;
        targetOn: string | undefined;
      };
    }
  | { type: "respond_notice"; noticeId: RecordId; response: NoticeResponse }
);

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const noticeWriteTypes: readonly string[] = Object.keys({
  create_notice: true,
  respond_notice: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<NoticeWrite["type"], true>);
