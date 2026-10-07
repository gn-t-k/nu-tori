import { recordIdSchema } from "../../domain/record-id";

export const writeIdSchema = recordIdSchema.openapi({ description: "冪等の鍵" });
