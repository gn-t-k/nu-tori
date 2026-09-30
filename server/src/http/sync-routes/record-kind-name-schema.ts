import { z } from "@hono/zod-openapi";
import { httpRecordKinds } from "./http-record-kinds";

// 登録簿の種類の名前。openapi.json に列挙として書き出し、端末が自分の登録簿と突き合わせる
// 応答を解くのには使わない（取りに行く変更の種類は文字列で持ち、知らない種類は読み飛ばす）
export const recordKindNameSchema = z
  .enum(httpRecordKinds.map(({ name }) => name))
  .openapi("RecordKindName", {
    description:
      "サーバーが同期で扱う記録の種類の名前。応答の kind を解くのには使わない（知らない種類を読み飛ばすため、応答では文字列で持つ）",
  });
