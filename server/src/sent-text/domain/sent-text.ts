import type { RecordId } from "../../domain/record-id";

// 送った文章（ユーザーの発言）。端末が作り、作ったあと変わらない
export type SentText = {
  id: RecordId;
  // 端末が送ったまま持つ。前後の空白を除いて 1〜500 のコードポイント
  body: string;
  // 送る操作をした時刻
  sentAt: Date;
  // 送ったときのタイムゾーン（IANA 名）
  timeZone: string;
};
