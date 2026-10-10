import { z } from "zod";
import { recordIdSchema } from "../../../domain/record-id";

// Sonnet 5.5 の返事の答え。body を先に置く（構造化出力はこの順に出すので、流しながら本文を先に読める）
export const sonnetReplyOutputSchema = z.object({
  body: z.string(),
  mealIds: z.array(recordIdSchema),
});
