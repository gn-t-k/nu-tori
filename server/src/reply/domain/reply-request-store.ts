import type { RecordId } from "../../domain/record-id";

// 返事の依頼を書く置き場。依頼ときっかけのサブセットを、呼び出し側のトランザクションの中で一緒に書く
export type ReplyRequestStore = {
  insert: (request: ReplyRequest) => void;
};

export type ReplyRequest = {
  id: string;
  sentTextId: RecordId;
  // 依頼を作った時点の、ユーザーの最新のタイムゾーンでの日
  countedOn: string;
  // きっかけ。会話として送り直した・送り直したは、その書き込みを足すチケット（#427・#430）で足す
  trigger: { type: "classification" };
};
