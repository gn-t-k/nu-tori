import { generateRecordId } from "../../../domain/record-id";

export const resendSentTextWrite = (
  sentTextId: string,
  overrides: { id?: string } = {},
): { id: string; type: "resend_sent_text"; sentTextId: string } => ({
  id: overrides.id ?? generateRecordId(),
  type: "resend_sent_text",
  sentTextId,
});
