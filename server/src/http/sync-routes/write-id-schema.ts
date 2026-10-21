import { recordIdSchema } from "../../domain/record-id";

export const writeIdSchema = recordIdSchema.meta({ description: "冪等の鍵" });
