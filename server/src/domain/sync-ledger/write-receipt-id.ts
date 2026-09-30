// 控えの ID。作るのは帳簿だけ（コンストラクタを閉じているので、ほかは値を組み立てられない）
export class WriteReceiptId {
  private constructor(readonly value: string) {}

  static issue(writeId: string): WriteReceiptId {
    return new WriteReceiptId(writeId);
  }
}
