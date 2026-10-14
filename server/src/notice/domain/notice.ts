import type { RecordId } from "../../domain/record-id";

// 端末が出す知らせ。種類は、体重の記録忘れ（missed_weight_record）と、目標を立てる（goal_setup）
export type Notice = IssuedNotice & { response: NoticeResponse | undefined };

// 答えを除いた、出したときの知らせ
export type IssuedNotice = {
  id: RecordId;
  issuedAt: Date;
  timeZone: string;
} & NoticeSubject;

// 種類と、種類ごとに持つもの。対象の日付（YYYY-MM-DD）は記録忘れの知らせだけが持つ
export type NoticeSubject =
  | { noticeType: "missed_weight_record"; targetOn: string }
  | { noticeType: "goal_setup" };

export type NoticeResponse = { respondedAt: Date; timeZone: string };

// 種類の一覧。表の列の列挙がここから引く。足したら NoticeSubject にも足す（種類ごとの match が型エラーで止める）
export const noticeTypes = ["missed_weight_record", "goal_setup"] as const;

export type NoticeType = (typeof noticeTypes)[number];

export const isNoticeType = (value: string): value is NoticeType =>
  noticeTypes.some((noticeType) => noticeType === value);
