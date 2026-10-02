// 端末が出す知らせ。この仕様の種類は体重の記録忘れ（missed_weight_record）だけ
export type Notice = {
  id: string;
  noticeType: NoticeType;
  issuedAt: Date;
  timeZone: string;
  // 記録忘れの対象の日付（YYYY-MM-DD）
  targetOn: string;
  response: NoticeResponse | undefined;
};

export type NoticeResponse = { respondedAt: Date; timeZone: string };

export const noticeTypes = ["missed_weight_record"] as const;

export type NoticeType = (typeof noticeTypes)[number];

export const isNoticeType = (value: string): value is NoticeType =>
  noticeTypes.some((noticeType) => noticeType === value);
