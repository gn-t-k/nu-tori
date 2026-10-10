import { generateRecordId } from "../../../domain/record-id";

export const resendSentTextAsConversationWrite = (
  sentTextId: string,
  overrides: { id?: string } = {},
): { id: string; type: "resend_sent_text_as_conversation"; sentTextId: string } => ({
  id: overrides.id ?? generateRecordId(),
  type: "resend_sent_text_as_conversation",
  sentTextId,
});
