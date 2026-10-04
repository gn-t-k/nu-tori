import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";

// 記録の種類が受け口に見せる入口。種類の名前をキーにした表（http-record-kinds.ts）に1行ずつ並べる。
// 書き込みの並び、OpenAPI の部品、取りに行く変更の kind は、この表から導く。メソッドの書き方は、型の違う種類を1つの型で扱うため（引数を双変にする）
export type HttpRecordKind<
  TValue = unknown,
  TWriteSchema extends WriteSchema = WriteSchema,
  TRecordSchema extends z.ZodObject = z.ZodObject,
> = {
  // サーバーだけが書く種類は、端末からの書き込みを宣言しない
  writes: HttpKindWrites<TWriteSchema> | undefined;
  // 削除の印を持つか。持たない種類で削除の印を読んだら、不具合として投げる
  keepsDeletionMarks: boolean;
  // 取りに行く変更の record の形。openapi.json に、種類の名前から作った名前（weight_trend なら WeightTrendRecord）の部品として書き出す
  recordSchema: TRecordSchema;
  toRecord(value: TValue, recordId: string): z.input<TRecordSchema>;
};

// 端末からの書き込みのスキーマ。type の値で、どの種類の書き込みかを決める
type WriteSchema = z.ZodObject<{ type: z.ZodLiteral<string> }>;

type HttpKindWrites<TWriteSchema extends WriteSchema> = {
  schemas: readonly TWriteSchema[];
  toWrite(write: z.infer<TWriteSchema>): SyncWrite;
};
