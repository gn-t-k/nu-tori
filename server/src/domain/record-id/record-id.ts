import { z } from "zod";

// API と DB の UUID の文字列は、小文字の正規形（RFC 9562 の出し方）だけにする。
// ID は文字列のまま比べるので、大文字の綴りを黙って直さず、受け口で断る（#362）
export const recordIdSchema = z
  .string()
  .regex(/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/, "UUID を小文字の正規形で書く")
  .meta({ format: "uuid" })
  .brand<"RecordId">();

export type RecordId = z.infer<typeof recordIdSchema>;

export const generateRecordId = (): RecordId => recordIdSchema.parse(crypto.randomUUID());
