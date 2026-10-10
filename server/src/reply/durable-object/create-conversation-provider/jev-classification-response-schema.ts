import { z } from "zod";

// Jev の答えのうち、読み分けに使うところ。noul は「食事である」の確からしさ（0〜1）
export const jevClassificationResponseSchema = z.object({
  answers: z.object({
    is_meal: z.object({ type: z.literal("noul"), noul: z.number().min(0).max(1) }),
  }),
  usage: z.object({ input_tokens: z.number(), output_tokens: z.number() }),
});
