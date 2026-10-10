import { z } from "zod";

// Haiku 5.5 の読み分けの答え。unsure は会話として扱う
export const haikuClassificationOutputSchema = z.object({
  label: z.enum(["meal", "conversation", "unsure"]),
});
